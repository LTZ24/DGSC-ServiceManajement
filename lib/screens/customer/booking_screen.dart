import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/cf_engine.dart';
import '../../services/firebase_db_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/diagnosis_dialog.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();
  final _issueController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _preferredDate;
  bool _isLoading = false;
  String _selectedDeviceType = 'Handphone';
  String? _selectedBrand;

  // Diagnosis data (CF-based)
  List<CfResult>? _diagnosisResults;
  CfCategory? _diagnosisCategory;
  List<CfSymptom>? _diagnosisSymptoms;

  final List<String> _deviceTypes = ['Handphone', 'Laptop'];
  final List<String> _brands = [
    'Samsung', 'Apple', 'Xiaomi', 'OPPO', 'Vivo', 'Realme',
    'Asus', 'Lenovo', 'HP', 'Dell', 'Acer', 'MSI', 'Lainnya',
  ];

  @override
  void dispose() {
    _modelController.dispose();
    _serialController.dispose();
    _issueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date != null) setState(() => _preferredDate = date);
  }

  void _openDiagnosis() {
    showDialog(
      context: context,
      builder: (_) => DiagnosisDialog(
        onResultSelected: (results, category, symptoms) {
          setState(() {
            _diagnosisResults = results;
            _diagnosisCategory = category;
            _diagnosisSymptoms = symptoms;
            if (category.name.toLowerCase().contains('handphone')) {
              _selectedDeviceType = 'Handphone';
            } else {
              _selectedDeviceType = 'Laptop';
            }
            if (results.isNotEmpty) {
              final top = results.first;
              _issueController.text =
                  'Diagnosis: ${top.damage.name} (${top.cfPercentage.toStringAsFixed(1)}%)';
            }
          });
        },
      ),
    );
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = FirebaseDbService.currentUser;
    final uid = user?.uid ?? '';

    final data = <String, dynamic>{
      'customer_id': uid,
      'customer_name': user?.displayName ?? '',
      'customer_phone': '',
      'device_type': _selectedDeviceType,
      'brand': _selectedBrand ?? '',
      'model': _modelController.text.trim(),
      'serial_number': _serialController.text.trim(),
      'issue_description': _issueController.text.trim(),
      'notes': _notesController.text.trim(),
      'status': 'pending',
    };

    if (_preferredDate != null) {
      data['preferred_date'] =
          DateFormat('yyyy-MM-dd').format(_preferredDate!);
    }

    if (_diagnosisResults != null && _diagnosisCategory != null) {
      data['diagnosis_category'] = _diagnosisCategory!.name;
      data['diagnosis_symptoms'] =
          _diagnosisSymptoms?.map((s) => s.name).join(', ') ?? '';
      data['diagnosis_result'] = _diagnosisResults!
          .map((r) =>
              '${r.damage.name}: ${r.cfPercentage.toStringAsFixed(1)}%')
          .join('; ');
      data['diagnosis_cf_percentage'] = _diagnosisResults!.isNotEmpty
          ? _diagnosisResults!.first.cfPercentage
          : 0;
    }

    try {
      await FirebaseDbService.addBooking(data);

      // Save diagnosis history if diagnosis was done
      if (_diagnosisResults != null && _diagnosisCategory != null) {
        await FirebaseDbService.saveDiagnosisHistory(
          categoryId: _diagnosisCategory!.id,
          categoryName: _diagnosisCategory!.name,
          deviceInfo: '$_selectedDeviceType ${_selectedBrand ?? ""} ${_modelController.text.trim()}',
          selectedSymptomIds:
              _diagnosisSymptoms?.map((s) => s.id).toList() ?? [],
          results: _diagnosisResults!
              .map((r) => {
                    'damage_id': r.damage.id,
                    'damage_name': r.damage.name,
                    'cf_combined': r.cfCombined,
                    'cf_percentage': r.cfPercentage,
                  })
              .toList(),
          topDiagnosis: _diagnosisResults!.first.damage.name,
          cfPercentage: _diagnosisResults!.first.cfPercentage,
          userId: uid,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Booking berhasil dikirim!'),
          backgroundColor: AppTheme.successColor,
        ));
        Navigator.pushReplacementNamed(context, '/customer/status');
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: ${e.message}'),
          backgroundColor: AppTheme.dangerColor,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Servis')),
      drawer: const AppDrawer(isAdmin: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Diagnosis Card ────────────────────────────────────
              Card(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                child: InkWell(
                  onTap: _openDiagnosis,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const Icon(Icons.medical_services,
                          color: AppTheme.accentColor, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Diagnosis Kerusakan',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                              _diagnosisResults != null
                                  ? 'Hasil: ${_diagnosisResults!.first.damage.name}'
                                  : 'Cek kerusakan perangkat Anda (opsional)',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Device Info ───────────────────────────────────────
              Text('Informasi Perangkat',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedDeviceType,
                decoration: const InputDecoration(
                    labelText: 'Jenis Perangkat',
                    prefixIcon: Icon(Icons.devices)),
                items: _deviceTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedDeviceType = val!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                    labelText: 'Merek',
                    prefixIcon: Icon(Icons.branding_watermark)),
                items: _brands
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedBrand = val),
                validator: (v) => v == null ? 'Pilih merek' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                    labelText: 'Model',
                    prefixIcon: Icon(Icons.phone_android),
                    hintText: 'Contoh: Galaxy S21, iPhone 14'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Model wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serialController,
                decoration: const InputDecoration(
                    labelText: 'Nomor Seri (opsional)',
                    prefixIcon: Icon(Icons.qr_code)),
              ),
              const SizedBox(height: 20),

              // ── Problem ───────────────────────────────────────────
              Text('Detail Masalah',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _issueController,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Deskripsi Kerusakan',
                    alignLabelWithHint: true,
                    hintText: 'Jelaskan masalah perangkat Anda...'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Deskripsi wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Tanggal Preferensi',
                      prefixIcon: Icon(Icons.calendar_today)),
                  child: Text(
                    _preferredDate != null
                        ? DateFormat('dd MMMM yyyy', 'id')
                            .format(_preferredDate!)
                        : 'Pilih tanggal',
                    style: TextStyle(
                        color: _preferredDate != null ? null : Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Catatan Tambahan (opsional)',
                    alignLabelWithHint: true),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitBooking,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: Text(_isLoading ? 'Mengirim...' : 'Kirim Booking'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}