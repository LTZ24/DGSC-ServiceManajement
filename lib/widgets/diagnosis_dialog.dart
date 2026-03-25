import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../services/cf_engine.dart';
import '../services/diagnosis_config_service.dart';

class DiagnosisDialog extends StatefulWidget {
  final void Function(
    List<CfResult> results,
    CfCategory category,
    List<CfSymptom> selectedSymptoms,
  )? onResultSelected;

  const DiagnosisDialog({super.key, this.onResultSelected});

  @override
  State<DiagnosisDialog> createState() => _DiagnosisDialogState();
}

class _DiagnosisDialogState extends State<DiagnosisDialog> {
  int _step = 0;
  CfCategory? _selectedCategory;
  List<CfSymptom> _symptoms = [];
  final Set<int> _selectedSymptomIds = {};
  List<CfResult> _results = [];
  bool _isLoading = false;
  bool _isPreparing = true;
  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _prepareDataset();
  }

  Future<void> _prepareDataset() async {
    await DiagnosisConfigService.syncPublishedDataset();
    if (mounted) {
      setState(() => _isPreparing = false);
    }
  }

  List<CfCategory> get _categories => CfEngine.categories;

  void _loadSymptoms(CfCategory category) {
    setState(() {
      _selectedCategory = category;
      _symptoms = CfEngine.getSymptomsForCategory(category.id);
      _selectedSymptomIds.clear();
      _step = 1;
    });
  }

  void _calculateDiagnosis() {
    if (_selectedSymptomIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 gejala')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final results = CfEngine.diagnose(
      categoryId: _selectedCategory!.id,
      selectedSymptomIds: _selectedSymptomIds.toList(),
    );
    setState(() {
      _results = results;
      _isLoading = false;
      _step = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFD9E2EC);
    final backgroundColor = isDark ? AppTheme.darkSurface : Colors.white;
    final mutedColor =
        isDark ? AppTheme.darkMutedText : const Color(0xFF64748B);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.12),
              blurRadius: 36,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1D4ED8),
                              Color(0xFF0EA5E9),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.monitor_heart_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diagnosis Kerusakan',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _stepLabel,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: mutedColor,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: isDark ? 0.26 : 0.64),
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _StepProgress(
                    step: _step,
                    labels: [
                      'Perangkat',
                      'Gejala',
                      'Hasil',
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),
            Expanded(
              child: _isPreparing
                  ? _buildLoadingState(
                      'Menyiapkan data diagnosis...',
                      'Dataset sedang disinkronkan.',
                    )
                  : _isLoading
                      ? _buildLoadingState(
                          'Memproses diagnosis...',
                          'Sistem sedang menghitung hasil terbaik.',
                        )
                      : _buildStepContent(),
            ),
            if (!_isLoading && !_isPreparing)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: _buildActions(),
              ),
          ],
        ),
      ),
    );
  }

  String get _stepLabel {
    switch (_step) {
      case 0:
        return 'Langkah 1 dari 3 • Pilih jenis perangkat yang ingin diperiksa.';
      case 1:
        return 'Langkah 2 dari 3 • Pilih gejala yang muncul pada perangkat.';
      case 2:
        return 'Langkah 3 dari 3 • Tinjau hasil diagnosis dan solusi awal.';
      default:
        return '';
    }
  }

  Widget _buildLoadingState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildCategoryStep();
      case 1:
        return _buildSymptomsStep();
      case 2:
        return _buildResultsStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCategoryStep() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final cat = _categories[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _loadSymptoms(cat),
            child: Ink(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.9),
                ),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.32),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _categoryIcon(cat.name),
                      color: const Color(0xFF1D4ED8),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat.description,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.5,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSymptomsStep() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _symptoms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final symptom = _symptoms[index];
        final isSelected = _selectedSymptomIds.contains(symptom.id);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1D4ED8)
                  : Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.9),
            ),
            color: isSelected
                ? const Color(0xFFEFF6FF)
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.22),
          ),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedSymptomIds.add(symptom.id);
                } else {
                  _selectedSymptomIds.remove(symptom.id);
                }
              });
            },
            checkboxShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              symptom.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            subtitle: symptom.description == null
                ? Text(
                    symptom.code,
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          symptom.description!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          symptom.code,
                          style: const TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildResultsStep() {
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada hasil diagnosis',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final result = _results[index];
        final percentage = result.cfPercentage;
        final resultColor = _getCfColor(percentage);
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: resultColor.withValues(alpha: 0.18)),
            color: resultColor.withValues(alpha: 0.07),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      result.damage.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: resultColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: resultColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: result.cfCombined.clamp(0.0, 1.0),
                  minHeight: 9,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation(resultColor),
                ),
              ),
              if (result.damage.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  result.damage.description!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
              if (result.damage.solution != null) ...[
                const SizedBox(height: 12),
                _ResultInfoRow(
                  icon: Icons.lightbulb_outline_rounded,
                  color: AppTheme.warningColor,
                  text: 'Solusi: ${result.damage.solution!}',
                ),
              ],
              if (result.damage.estimatedCost != null) ...[
                const SizedBox(height: 8),
                _ResultInfoRow(
                  icon: Icons.payments_outlined,
                  color: AppTheme.successColor,
                  text:
                      'Estimasi Biaya: ${currencyFormat.format(result.damage.estimatedCost)}',
                ),
              ],
              if (result.damage.estimatedTime != null) ...[
                const SizedBox(height: 8),
                _ResultInfoRow(
                  icon: Icons.schedule_outlined,
                  color: const Color(0xFF1D4ED8),
                  text: 'Estimasi Waktu: ${result.damage.estimatedTime}',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  IconData _categoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('laptop')) return Icons.laptop_mac_outlined;
    if (lower.contains('tablet')) return Icons.tablet_mac_outlined;
    return Icons.phone_android_rounded;
  }

  Color _getCfColor(double percentage) {
    if (percentage >= 80) return AppTheme.successColor;
    if (percentage >= 60) return AppTheme.infoColor;
    if (percentage >= 40) return AppTheme.warningColor;
    return AppTheme.dangerColor;
  }

  Widget _buildActions() {
    return Row(
      children: [
        if (_step > 0)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _step--;
                if (_step == 0) {
                  _selectedSymptomIds.clear();
                  _selectedCategory = null;
                  _symptoms = [];
                }
              }),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Kembali'),
            ),
          ),
        if (_step > 0) const SizedBox(width: 12),
        if (_step == 1)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _calculateDiagnosis,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Lihat Hasil'),
            ),
          ),
        if (_step == 2 && widget.onResultSelected != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                final selectedSymptoms = _symptoms
                    .where((s) => _selectedSymptomIds.contains(s.id))
                    .toList();
                widget.onResultSelected!(
                  _results,
                  _selectedCategory!,
                  selectedSymptoms,
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Gunakan Hasil'),
            ),
          ),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({
    required this.step,
    required this.labels,
  });

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (index) {
        final isActive = index <= step;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF1D4ED8)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  labels[index],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isActive
                            ? const Color(0xFF1D4ED8)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _ResultInfoRow extends StatelessWidget {
  const _ResultInfoRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                ),
          ),
        ),
      ],
    );
  }
}
