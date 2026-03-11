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
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medical_services, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Diagnosis Kerusakan',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        Text(_stepLabel,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? AppTheme.primaryColor
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
            ),
            Expanded(
              child: _isPreparing
                  ? const Center(child: CircularProgressIndicator())
                  : _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildStepContent(),
            ),
            if (!_isLoading && !_isPreparing) _buildActions(),
          ],
        ),
      ),
    );
  }

  String get _stepLabel {
    switch (_step) {
      case 0:
        return 'Langkah 1: Pilih Jenis Perangkat';
      case 1:
        return 'Langkah 2: Pilih Gejala (${_selectedSymptomIds.length} dipilih)';
      case 2:
        return 'Langkah 3: Hasil Diagnosis';
      default:
        return '';
    }
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final cat = _categories[index];
        return Card(
          child: ListTile(
            leading: Icon(
              cat.name.toLowerCase().contains('handphone')
                  ? Icons.phone_android
                  : Icons.laptop,
              color: AppTheme.primaryColor,
              size: 32,
            ),
            title: Text(cat.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(cat.description),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _loadSymptoms(cat),
          ),
        );
      },
    );
  }

  Widget _buildSymptomsStep() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _symptoms.length,
      itemBuilder: (context, index) {
        final symptom = _symptoms[index];
        final isSelected = _selectedSymptomIds.contains(symptom.id);
        return CheckboxListTile(
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
          title: Text(symptom.name, style: const TextStyle(fontSize: 14)),
          subtitle: symptom.description != null ? Text(symptom.description!) : null,
          secondary: Text(symptom.code,
              style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
        );
      },
    );
  }

  Widget _buildResultsStep() {
    if (_results.isEmpty) {
      return const Center(
        child: Text('Tidak ada hasil diagnosis',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        final percentage = result.cfPercentage;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(result.damage.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getCfColor(percentage).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: _getCfColor(percentage),
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: result.cfCombined.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        AlwaysStoppedAnimation(_getCfColor(percentage)),
                    minHeight: 6,
                  ),
                ),
                if (result.damage.description != null) ...[
                  const SizedBox(height: 8),
                  Text(result.damage.description!,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                if (result.damage.solution != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 14, color: AppTheme.warningColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('Solusi: ${result.damage.solution!}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
                if (result.damage.estimatedCost != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Estimasi Biaya: ${currencyFormat.format(result.damage.estimatedCost)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.successColor),
                  ),
                ],
                if (result.damage.estimatedTime != null)
                  Text('Estimasi Waktu: ${result.damage.estimatedTime}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getCfColor(double percentage) {
    if (percentage >= 80) return AppTheme.successColor;
    if (percentage >= 60) return AppTheme.infoColor;
    if (percentage >= 40) return AppTheme.warningColor;
    return AppTheme.dangerColor;
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _step--;
                  if (_step == 0) _selectedSymptomIds.clear();
                }),
                child: const Text('Kembali'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          if (_step == 1)
            Expanded(
              child: ElevatedButton(
                onPressed: _calculateDiagnosis,
                child: const Text('Diagnosis'),
              ),
            ),
          if (_step == 2 && widget.onResultSelected != null)
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final selectedSymptoms = _symptoms
                      .where((s) => _selectedSymptomIds.contains(s.id))
                      .toList();
                  widget.onResultSelected!(
                      _results, _selectedCategory!, selectedSymptoms);
                  Navigator.pop(context);
                },
                child: const Text('Gunakan Hasil'),
              ),
            ),
        ],
      ),
    );
  }
}
