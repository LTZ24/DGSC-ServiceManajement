import 'dart:convert';

import 'package:flutter/material.dart';

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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.infoColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _validationMessage!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Editor JSON', 'JSON Editor'),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                  'Format wajib memiliki kunci: categories, symptoms, damages, rules.',
                  'The format must include the keys: categories, symptoms, damages, rules.'),
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 420,
              child: TextField(
                controller: _jsonController,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.45,
                ),
                decoration: InputDecoration(
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  hintText:
                      '{\n  "categories": [],\n  "symptoms": [],\n  "damages": [],\n  "rules": []\n}',
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
}
