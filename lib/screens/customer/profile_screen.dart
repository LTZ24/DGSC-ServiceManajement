import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_db_service.dart';
import '../../widgets/app_drawer.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final uid = FirebaseDbService.currentUser?.uid ?? '';
    _profile = await FirebaseDbService.getUserProfile(uid);
    if (_profile != null) {
      _nameController.text = _profile!['username'] ?? '';
      _phoneController.text = _profile!['phone'] ?? '';
      _emailController.text = _profile!['email'] ?? '';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final uid = FirebaseDbService.currentUser?.uid ?? '';
    try {
      await FirebaseDbService.updateUserProfile(uid, {
        'username': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profil berhasil diperbarui'),
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

  Future<void> _showPasswordRequestDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Permintaan ubah password akan dikirim ke admin untuk disetujui.'),
            SizedBox(height: 8),
            Text(
              'Setelah disetujui, link reset password akan dikirim ke email Anda.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kirim Permintaan')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final uid = FirebaseDbService.currentUser?.uid ?? '';
    final email = _emailController.text.trim();
    final username = _nameController.text.trim();

    try {
      await FirebaseDbService.addPasswordRequest(uid, email, username);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permintaan terkirim! Tunggu persetujuan admin.'),
          backgroundColor: AppTheme.successColor,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mengirim: $e'),
          backgroundColor: AppTheme.dangerColor,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      drawer: const AppDrawer(isAdmin: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        (_nameController.text.isNotEmpty
                                ? _nameController.text
                                : 'U')[0]
                            .toUpperCase(),
                        style: const TextStyle(
                            fontSize: 40,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: 'Nama / Username',
                        prefixIcon: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Nomor HP',
                        prefixIcon: Icon(Icons.phone)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    enabled: false,
                    decoration: const InputDecoration(
                        labelText: 'Email (tidak bisa diubah)',
                        prefixIcon: Icon(Icons.email)),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Simpan Perubahan'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Change Password Request
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.lock_reset, color: AppTheme.infoColor),
                      title: const Text('Ubah Password'),
                      subtitle: const Text('Kirim permintaan ke admin untuk ubah password'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showPasswordRequestDialog(),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Card(
                    color: AppTheme.dangerColor.withValues(alpha: 0.05),
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: AppTheme.dangerColor),
                      title: const Text('Keluar', style: TextStyle(color: AppTheme.dangerColor)),
                      onTap: () async {
                        final authProvider = context.read<AuthProvider>();
                        await authProvider.logout();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}