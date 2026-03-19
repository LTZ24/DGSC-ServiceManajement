import 'package:flutter/material.dart';
import '../../services/app_lock_service.dart';
import '../../config/theme.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  bool _enabled = false;
  String? _currentPin;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final enabled = await AppLockService.isEnabled();
    final pin = await AppLockService.getPin();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _currentPin = pin;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLock(bool val) async {
    if (val && _currentPin == null) {
      final newPin = await _showPinDialog('Buat PIN Baru');
      if (newPin != null && newPin.length >= 4) {
        await AppLockService.setPin(newPin);
        await AppLockService.setEnabled(true);
        _loadData();
      }
    } else {
      await AppLockService.setEnabled(val);
      _loadData();
    }
  }

  Future<void> _changePin() async {
    final oldPin = await _showPinDialog('Masukkan PIN Saat Ini');
    if (oldPin != _currentPin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN saat ini salah', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.dangerColor),
        );
      }
      return;
    }
    final newPin = await _showPinDialog('Buat PIN Baru');
    if (newPin != null && newPin.length >= 4) {
      await AppLockService.setPin(newPin);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN berhasil diubah', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.successColor),
        );
      }
    }
  }

  Future<String?> _showPinDialog(String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(
            hintText: 'Min 4 digit',
            counterText: '',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan App Lock')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SwitchListTile(
              secondary: const Icon(Icons.lock_outline, color: AppTheme.primaryColor),
              title: const Text('Gunakan App Lock'),
              subtitle: const Text('Kunci aplikasi saat tidak aktif selama 5 menit atau keluar dari recent apps'),
              value: _enabled,
              onChanged: _toggleLock,
            ),
          ),
          if (_enabled) ...[
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.pin, color: AppTheme.primaryColor),
                title: const Text('Ubah PIN'),
                subtitle: const Text('Perbarui PIN keamanan App Lock Anda'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _changePin,
              ),
            ),
          ],
        ],
      ),
    );
  }
}