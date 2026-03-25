import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/backend_types.dart';
import '../../services/cf_engine.dart';
import '../../services/diagnosis_config_service.dart';
import '../../widgets/app_drawer.dart';

class AdminDiagnosisEditorScreen extends StatefulWidget {
  const AdminDiagnosisEditorScreen({super.key});

  @override
  State<AdminDiagnosisEditorScreen> createState() =>
      _AdminDiagnosisEditorScreenState();
}

class _AdminDiagnosisEditorScreenState
    extends State<AdminDiagnosisEditorScreen> {
  final TextEditingController _jsonController = TextEditingController();
  final ScrollController _editorScrollController = ScrollController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _config;
  Map<String, int> _summary = const {
    'categories': 0,
    'symptoms': 0,
    'damages': 0,
    'rules': 0,
  };
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _loadEditor();
  }

  @override
  void dispose() {
    _editorScrollController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _loadEditor() async {
    setState(() => _isLoading = true);
    try {
      final data = await DiagnosisConfigService.loadEditorDocument();
      if (!mounted) return;
      setState(() {
        _config = data['config'] as Map<String, dynamic>?;
        _summary = Map<String, int>.from(data['summary'] as Map);
        _jsonController.text = data['jsonText'] as String;
        _validationMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validationMessage = 'Gagal memuat data diagnosis: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _validateOnly() async {
    try {
      final summary =
          DiagnosisConfigService.summarizeJson(_jsonController.text);
      setState(() {
        _summary = summary;
        _validationMessage = 'JSON valid. Data siap disimpan atau dipublish.';
      });
    } catch (e) {
      setState(() {
        _validationMessage = 'Validasi gagal: $e';
      });
    }
  }

  Future<String?> _askPassword(String actionLabel) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
              '$actionLabel ${context.tr('Data Diagnosis', 'Diagnosis Data')}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.tr('Password admin', 'Admin password'),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr(
                      'Password wajib diisi', 'Password is required');
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Batal', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _runProtectedAction({
    required String actionLabel,
    required Future<void> Function(String password) onSubmit,
  }) async {
    final password = await _askPassword(actionLabel);
    if (password == null) return;

    setState(() => _isSubmitting = true);
    try {
      await onSubmit(password);
    } on BackendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('Gagal', 'Failed')}: $e'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _saveDraft() async {
    await _runProtectedAction(
      actionLabel: context.tr('Simpan Draft', 'Save Draft'),
      onSubmit: (password) async {
        final summary = await DiagnosisConfigService.saveDraft(
          jsonText: _jsonController.text,
          password: password,
        );
        if (!mounted) return;
        setState(() {
          _summary = summary;
          _validationMessage = context.tr(
              'Draft berhasil disimpan ke cloud dan lokal.',
              'Draft saved to cloud and local storage successfully.');
        });
        await _loadEditor();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Draft diagnosis berhasil disimpan',
                'Diagnosis draft saved successfully')),
            backgroundColor: AppTheme.successColor,
          ),
        );
      },
    );
  }

  Future<void> _publish() async {
    await _runProtectedAction(
      actionLabel: context.tr('Publish', 'Publish'),
      onSubmit: (password) async {
        final result = await DiagnosisConfigService.publishDataset(
          jsonText: _jsonController.text,
          password: password,
        );
        if (!mounted) return;
        setState(() {
          _summary = Map<String, int>.from(result['summary'] as Map);
          _validationMessage = context.tr(
              'Publish berhasil. Versi ${result['version']} siap disinkronkan ke semua aplikasi.',
              'Publish successful. Version ${result['version']} is ready to be synced to all applications.');
        });
        await _loadEditor();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(
                'Diagnosis versi ${result['version']} berhasil dipublish',
                'Diagnosis version ${result['version']} published successfully')),
            backgroundColor: AppTheme.successColor,
          ),
        );
      },
    );
  }

  Future<void> _restorePublished() async {
    setState(() => _isLoading = true);
    try {
      final jsonText = await DiagnosisConfigService.loadPublishedJsonText();
      final summary = DiagnosisConfigService.summarizeJson(jsonText);
      if (!mounted) return;
      setState(() {
        _jsonController.text = jsonText;
        _summary = summary;
        _validationMessage = 'Editor dikembalikan ke data publish terbaru.';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validationMessage = 'Gagal memulihkan data publish: $e';
        _isLoading = false;
      });
    }
  }

  void _useDefaultTemplate() {
    final jsonText = const JsonEncoder.withIndent('  ')
        .convert(CfEngine.exportDefaultDatasetMap());
    final summary = DiagnosisConfigService.summarizeJson(jsonText);
    setState(() {
      _jsonController.text = jsonText;
      _summary = summary;
      _validationMessage = context.tr(
          'Template default berhasil dimuat ke editor.',
          'Default template loaded into the editor successfully.');
    });
  }

  Future<void> _formatJson() async {
    try {
      final decoded = json.decode(_jsonController.text);
      final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
      setState(() {
        _jsonController.text = pretty;
        _jsonController.selection = TextSelection.collapsed(
          offset: pretty.length,
        );
        _validationMessage = context.tr(
          'JSON berhasil dirapikan.',
          'JSON formatted successfully.',
        );
      });
    } catch (e) {
      setState(() {
        _validationMessage = '${context.tr('Format gagal', 'Format failed')}: $e';
      });
    }
  }

  Future<void> _copyJson() async {
    await Clipboard.setData(ClipboardData(text: _jsonController.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'JSON berhasil disalin.',
            'JSON copied successfully.',
          ),
        ),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  int get _lineCount {
    if (_jsonController.text.isEmpty) return 0;
    return '\n'.allMatches(_jsonController.text).length + 1;
  }

  int get _characterCount => _jsonController.text.length;

  bool get _hasValidationError {
    final message = _validationMessage?.toLowerCase() ?? '';
    return message.contains('gagal') || message.contains('failed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title:
              Text(context.tr('Edit Data Diagnosis', 'Edit Diagnosis Data'))),
      drawer: const AppDrawer(isAdmin: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 16),
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _buildEditorCard(),
                      const SizedBox(height: 16),
                      if (_validationMessage != null)
                        _buildValidationBanner(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSubmitting ? null : _validateOnly,
                                icon: const Icon(Icons.verified_outlined),
                                label: Text(context.tr('Validasi', 'Validate')),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSubmitting ? null : _saveDraft,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(
                                    context.tr('Simpan Draft', 'Save Draft')),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _publish,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.publish_outlined),
                            label: Text(context.tr('Publish ke Semua User',
                                'Publish to All Users')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoCard() {
    final publishedVersion = _config?['published_version']?.toString() ?? '-';
    final draftVersion = _config?['draft_version']?.toString() ?? '-';
    final publishedAt = _config?['published_at']?.toString() ?? '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.84),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Kelola JSON Diagnosis', 'Manage Diagnosis JSON'),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
                'Perubahan draft disimpan ke Supabase dan perangkat admin. Saat publish, semua aplikasi akan mengunduh versi terbaru secara otomatis saat sinkronisasi berikutnya.',
                'Draft changes are saved to Supabase and the admin device. When published, all apps will automatically download the latest version on the next sync.'),
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _pill(context.tr('Versi publish', 'Published version'),
                  publishedVersion),
              _pill(context.tr('Versi draft', 'Draft version'), draftVersion),
              _pill(context.tr('Publish terakhir', 'Last published'),
                  publishedAt),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Ringkasan Dataset', 'Dataset Summary'),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summaryChip(context.tr('Kategori', 'Categories'),
                    _summary['categories'] ?? 0),
                _summaryChip(context.tr('Gejala', 'Symptoms'),
                    _summary['symptoms'] ?? 0),
                _summaryChip(context.tr('Kerusakan', 'Damages'),
                    _summary['damages'] ?? 0),
                _summaryChip('Rule CF', _summary['rules'] ?? 0),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _restorePublished,
                  icon: const Icon(Icons.restore_outlined),
                  label: Text(
                      context.tr('Ambil Data Publish', 'Load Published Data')),
                ),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _useDefaultTemplate,
                  icon: const Icon(Icons.restart_alt_outlined),
                  label:
                      Text(context.tr('Template Default', 'Default Template')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorCard() {
    final helperColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final surfaceTint =
        Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.28,
            );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Editor JSON', 'JSON Editor'),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _formatJson,
                      icon: const Icon(Icons.auto_fix_high_outlined),
                      label: Text(context.tr('Rapikan', 'Format')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _copyJson,
                      icon: const Icon(Icons.content_copy_outlined),
                      label: Text(context.tr('Salin', 'Copy')),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Pastikan struktur utama tetap memakai categories, symptoms, damages, dan rules.',
                'Keep the top-level structure as categories, symptoms, damages, and rules.',
              ),
              style: TextStyle(color: helperColor, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _EditorKeyChip(label: 'categories'),
                _EditorKeyChip(label: 'symptoms'),
                _EditorKeyChip(label: 'damages'),
                _EditorKeyChip(label: 'rules'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _editorStat(
                    context.tr('Baris', 'Lines'),
                    _lineCount.toString(),
                  ),
                  _editorStat(
                    context.tr('Karakter', 'Characters'),
                    _characterCount.toString(),
                  ),
                  _editorStat(
                    context.tr('Versi Draft', 'Draft Version'),
                    _config?['draft_version']?.toString() ?? '-',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 440,
              decoration: BoxDecoration(
                color: surfaceTint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Scrollbar(
                controller: _editorScrollController,
                thumbVisibility: true,
                child: TextField(
                  controller: _jsonController,
                  scrollController: _editorScrollController,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.multiline,
                  onChanged: (_) {
                    if (_validationMessage == null) return;
                    setState(() => _validationMessage = null);
                  },
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.55,
                  ),
                  decoration: InputDecoration(
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.all(18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    hintText:
                        '{\n  "categories": [],\n  "symptoms": [],\n  "damages": [],\n  "rules": []\n}',
                    helperText: context.tr(
                      'Tip: gunakan tombol Rapikan sebelum Validasi atau Publish.',
                      'Tip: use Format before Validate or Publish.',
                    ),
                    helperStyle: TextStyle(
                      color: helperColor,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white, fontSize: 12.5),
      ),
    );
  }

  Widget _summaryChip(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildValidationBanner() {
    final isError = _hasValidationError;
    final color = isError ? AppTheme.dangerColor : AppTheme.infoColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _validationMessage!,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editorStat(String label, String value) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12.5),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorKeyChip extends StatelessWidget {
  const _EditorKeyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }
}
