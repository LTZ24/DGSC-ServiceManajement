import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/backend_service.dart';
import '../../widgets/app_drawer.dart';

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});
  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  final _storeNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _whatsAppCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccountNameCtrl = TextEditingController();
  final _bankAccountNumberCtrl = TextEditingController();
  final _openTimeCtrl = TextEditingController();
  final _closeTimeCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final List<String> _allDays = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
  ];
  List<String> _openDays = [];
  String? _qrisImageBase64;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _whatsAppCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountNameCtrl.dispose();
    _bankAccountNumberCtrl.dispose();
    _openTimeCtrl.dispose();
    _closeTimeCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final settings = await BackendService.getStoreSettings();
    setState(() {
      _storeNameCtrl.text = settings?['store_name'] ?? '';
      _phoneCtrl.text = settings?['phone'] ?? '';
      _emailCtrl.text = settings?['email'] ?? '';
      _addressCtrl.text = settings?['address'] ?? '';
      _whatsAppCtrl.text = settings?['whatsapp_phone'] ?? settings?['phone'] ?? '';
      _bankNameCtrl.text = settings?['bank_name'] ?? '';
      _bankAccountNameCtrl.text = settings?['bank_account_name'] ?? '';
      _bankAccountNumberCtrl.text = settings?['bank_account_number'] ?? '';
      _openTimeCtrl.text = settings?['open_time'] ?? '08:00';
      _closeTimeCtrl.text = settings?['close_time'] ?? '17:00';
      _descriptionCtrl.text = settings?['description'] ?? '';
      _qrisImageBase64 = settings?['qris_image_base64'];
      if (settings?['open_days'] is List) {
        _openDays = List<String>.from(settings!['open_days']);
      } else {
        _openDays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
      }
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await BackendService.saveStoreSettings({
        'store_name': _storeNameCtrl.text,
        'phone': _phoneCtrl.text,
        'email': _emailCtrl.text,
        'address': _addressCtrl.text,
        'whatsapp_phone': _whatsAppCtrl.text,
        'bank_name': _bankNameCtrl.text,
        'bank_account_name': _bankAccountNameCtrl.text,
        'bank_account_number': _bankAccountNumberCtrl.text,
        'qris_image_base64': _qrisImageBase64,
        'open_time': _openTimeCtrl.text,
        'close_time': _closeTimeCtrl.text,
        'description': _descriptionCtrl.text,
        'open_days': _openDays,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('Pengaturan berhasil disimpan', 'Settings saved successfully')),
          backgroundColor: AppTheme.successColor,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${context.tr('Gagal', 'Failed')}: $e'),
          backgroundColor: AppTheme.dangerColor,
        ));
      }
    }
    setState(() => _isSaving = false);
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    final parts = ctrl.text.split(':');
    final init = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final time = await showTimePicker(context: context, initialTime: init);
    if (time != null) {
      ctrl.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickQrisImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _qrisImageBase64 = base64Encode(bytes);
    });
  }

  String _dayLabel(BuildContext context, String day) {
    switch (day) {
      case 'Senin':
        return context.tr('Senin', 'Monday');
      case 'Selasa':
        return context.tr('Selasa', 'Tuesday');
      case 'Rabu':
        return context.tr('Rabu', 'Wednesday');
      case 'Kamis':
        return context.tr('Kamis', 'Thursday');
      case 'Jumat':
        return context.tr('Jumat', 'Friday');
      case 'Sabtu':
        return context.tr('Sabtu', 'Saturday');
      case 'Minggu':
        return context.tr('Minggu', 'Sunday');
      default:
        return day;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Pengaturan Toko', 'Store Settings')),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, color: Colors.white),
            label: Text(context.tr('Simpan', 'Save'),
                style: TextStyle(color: _isSaving ? Colors.white54 : Colors.white)),
          ),
        ],
      ),
      drawer: const AppDrawer(isAdmin: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSettings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionHeader(context.tr('Informasi Toko', 'Store Information')),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _storeNameCtrl,
                        decoration: InputDecoration(labelText: context.tr('Nama Toko', 'Store Name'), prefixIcon: const Icon(Icons.store)),
                        validator: (v) => v?.isEmpty == true ? context.tr('Wajib diisi', 'Required') : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(controller: _descriptionCtrl,
                          decoration: InputDecoration(labelText: context.tr('Deskripsi', 'Description'), prefixIcon: const Icon(Icons.description)),
                          maxLines: 3),
                      const SizedBox(height: 12),
                      TextFormField(controller: _addressCtrl,
                            decoration: InputDecoration(labelText: context.tr('Alamat', 'Address'), prefixIcon: const Icon(Icons.location_on)),
                          maxLines: 2),
                      const SizedBox(height: 24),
                          _sectionHeader(context.tr('Kontak', 'Contact')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
                          decoration: InputDecoration(labelText: context.tr('Telepon', 'Phone'), prefixIcon: const Icon(Icons.phone))),
                      const SizedBox(height: 12),
                      TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(labelText: context.tr('Email', 'Email'), prefixIcon: const Icon(Icons.email))),
                      const SizedBox(height: 12),
                      TextFormField(controller: _whatsAppCtrl, keyboardType: TextInputType.phone,
                            decoration: InputDecoration(labelText: context.tr('Nomor WhatsApp Admin', 'Admin WhatsApp Number'), prefixIcon: const Icon(Icons.chat))),
                      const SizedBox(height: 24),
                          _sectionHeader(context.tr('Pembayaran Customer', 'Customer Payment')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _bankNameCtrl,
                          decoration: InputDecoration(labelText: context.tr('Nama Bank', 'Bank Name'), prefixIcon: const Icon(Icons.account_balance))),
                      const SizedBox(height: 12),
                      TextFormField(controller: _bankAccountNumberCtrl, keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: context.tr('Nomor Rekening', 'Bank Account Number'), prefixIcon: const Icon(Icons.credit_card))),
                      const SizedBox(height: 12),
                      TextFormField(controller: _bankAccountNameCtrl,
                          decoration: InputDecoration(labelText: context.tr('Atas Nama Rekening', 'Account Holder Name'), prefixIcon: const Icon(Icons.person_outline))),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.qr_code_2, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      context.tr('QRIS Pembayaran', 'Payment QRIS'),
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _pickQrisImage,
                                    icon: const Icon(Icons.upload_file),
                                    label: Text(_qrisImageBase64 == null ? context.tr('Upload', 'Upload') : context.tr('Ganti', 'Change')),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr('Upload QRIS toko agar muncul di halaman pembayaran customer.', 'Upload the store QRIS so it appears on the customer payment page.'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_qrisImageBase64 != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    base64Decode(_qrisImageBase64!),
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        context.tr('QRIS belum diupload', 'QRIS not uploaded yet'),
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_qrisImageBase64 != null) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => setState(() => _qrisImageBase64 = null),
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.dangerColor),
                                    label: Text(context.tr('Hapus QRIS', 'Remove QRIS'), style: const TextStyle(color: AppTheme.dangerColor)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader(context.tr('Jam Operasional', 'Operating Hours')),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickTime(_openTimeCtrl),
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: _openTimeCtrl,
                                decoration: InputDecoration(
                                  labelText: context.tr('Jam Buka', 'Opening Time'),
                                  prefixIcon: const Icon(Icons.access_time),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickTime(_closeTimeCtrl),
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: _closeTimeCtrl,
                                decoration: InputDecoration(
                                  labelText: context.tr('Jam Tutup', 'Closing Time'),
                                  prefixIcon: const Icon(Icons.access_time_filled),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _sectionHeader(context.tr('Hari Buka', 'Open Days')),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _allDays.map((day) {
                          final isOpen = _openDays.contains(day);
                          return FilterChip(
                            label: Text(_dayLabel(context, day)),
                            selected: isOpen,
                            onSelected: (val) => setState(() {
                              if (val) {
                                _openDays.add(day);
                              } else {
                                _openDays.remove(day);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor));
  }
}
