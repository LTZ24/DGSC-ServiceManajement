import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/firebase_db_service.dart';
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
  final _openTimeCtrl = TextEditingController();
  final _closeTimeCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  final List<String> _allDays = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
  ];
  List<String> _openDays = [];

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
    _openTimeCtrl.dispose();
    _closeTimeCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final settings = await FirebaseDbService.getStoreSettings();
    setState(() {
      _storeNameCtrl.text = settings?['store_name'] ?? '';
      _phoneCtrl.text = settings?['phone'] ?? '';
      _emailCtrl.text = settings?['email'] ?? '';
      _addressCtrl.text = settings?['address'] ?? '';
      _openTimeCtrl.text = settings?['open_time'] ?? '08:00';
      _closeTimeCtrl.text = settings?['close_time'] ?? '17:00';
      _descriptionCtrl.text = settings?['description'] ?? '';
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
      await FirebaseDbService.saveStoreSettings({
        'store_name': _storeNameCtrl.text,
        'phone': _phoneCtrl.text,
        'email': _emailCtrl.text,
        'address': _addressCtrl.text,
        'open_time': _openTimeCtrl.text,
        'close_time': _closeTimeCtrl.text,
        'description': _descriptionCtrl.text,
        'open_days': _openDays,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pengaturan berhasil disimpan'),
          backgroundColor: AppTheme.successColor,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Toko'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, color: Colors.white),
            label: Text('Simpan',
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
                      _sectionHeader('Informasi Toko'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _storeNameCtrl,
                        decoration: const InputDecoration(labelText: 'Nama Toko', prefixIcon: Icon(Icons.store)),
                        validator: (v) => v?.isEmpty == true ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(controller: _descriptionCtrl,
                          decoration: const InputDecoration(labelText: 'Deskripsi', prefixIcon: Icon(Icons.description)),
                          maxLines: 3),
                      const SizedBox(height: 12),
                      TextFormField(controller: _addressCtrl,
                          decoration: const InputDecoration(labelText: 'Alamat', prefixIcon: Icon(Icons.location_on)),
                          maxLines: 2),
                      const SizedBox(height: 24),
                      _sectionHeader('Kontak'),
                      const SizedBox(height: 12),
                      TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Telepon', prefixIcon: Icon(Icons.phone))),
                      const SizedBox(height: 12),
                      TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email))),
                      const SizedBox(height: 24),
                      _sectionHeader('Jam Operasional'),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: GestureDetector(
                          onTap: () => _pickTime(_openTimeCtrl),
                          child: AbsorbPointer(child: TextFormField(
                              controller: _openTimeCtrl,
                              decoration: const InputDecoration(labelText: 'Jam Buka', prefixIcon: Icon(Icons.access_time)))),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: GestureDetector(
                          onTap: () => _pickTime(_closeTimeCtrl),
                          child: AbsorbPointer(child: TextFormField(
                              controller: _closeTimeCtrl,
                              decoration: const InputDecoration(labelText: 'Jam Tutup', prefixIcon: Icon(Icons.access_time_filled)))),
                        )),
                      ]),
                      const SizedBox(height: 24),
                      _sectionHeader('Hari Buka'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _allDays.map((day) {
                          final isOpen = _openDays.contains(day);
                          return FilterChip(
                            label: Text(day),
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