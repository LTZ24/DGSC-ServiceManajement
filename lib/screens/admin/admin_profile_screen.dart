import 'dart:io';

import 'package:flutter/material.dart';
import '../../l10n/app_text.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_service.dart';
import '../../services/local_storage_service.dart';
import '../../widgets/app_drawer.dart';
import 'package:provider/provider.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});
  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  bool get _isGooglePhoto {
    final value = _profile?['profile_picture']?.toString() ?? '';
    return value.startsWith('http://') || value.startsWith('https://');
  }

  ImageProvider<Object>? _buildProfileImage() {
    final value = _profile?['profile_picture']?.toString() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return NetworkImage(value);
    }

    final file = File(value);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

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

  Future<void> _loadProfile({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _isLoading = true);
    }
    final uid = BackendService.currentUser?.uid ?? '';
    final profile = await BackendService.getUserProfile(uid);
    if (!mounted) return;
    _profile = profile;
    if (_profile != null) {
      _nameController.text = _profile!['username'] ?? '';
      _phoneController.text = _profile!['phone'] ?? '';
      _emailController.text = _profile!['email'] ?? '';
    }
    if (showLoader) {
      setState(() => _isLoading = false);
    } else {
      setState(() {});
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final uid = BackendService.currentUser?.uid ?? '';
    try {
      await BackendService.updateUserProfile(uid, {
        'username': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      await _loadProfile(showLoader: false);
      if (mounted) {
        await context.read<AuthProvider>().refreshProfile();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr(
              'Profil berhasil diperbarui', 'Profile updated successfully')),
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

  Future<void> _pickProfilePhoto() async {
    final uid = BackendService.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final savedPath = await LocalStorageService.pickAndSaveProfilePhoto(uid);
      if (savedPath == null || savedPath.isEmpty) {
        setState(() => _isSaving = false);
        return;
      }

      await BackendService.updateProfilePicture(uid, savedPath);
      await _loadProfile(showLoader: false);
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('Foto profil berhasil diperbarui',
            'Profile photo updated successfully')),
        backgroundColor: AppTheme.successColor,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${context.tr('Gagal memperbarui foto profil', 'Failed to update profile photo')}: $e'),
          backgroundColor: AppTheme.dangerColor,
        ));
      }
    }
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _sendResetPasswordEmail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Ubah Password', 'Change Password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr(
                'Link reset password akan dikirim langsung ke email akun Anda.',
                'A password reset link will be sent directly to your account email.')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('Batal', 'Cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr('Kirim Email', 'Send Email'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    try {
      await BackendService.sendPasswordResetEmail(email);
      await BackendService.savePasswordResetRole('admin');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('Email reset password berhasil dikirim.',
              'Password reset email sent successfully.')),
          backgroundColor: AppTheme.successColor,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('${context.tr('Gagal mengirim', 'Failed to send')}: $e'),
          backgroundColor: AppTheme.dangerColor,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Profil', 'Profile'))),
      drawer: const AppDrawer(isAdmin: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _isGooglePhoto || _isSaving
                              ? null
                              : _pickProfilePhoto,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: AppTheme.primaryColor,
                                backgroundImage: _buildProfileImage(),
                                child: _buildProfileImage() == null
                                    ? Text(
                                        (_nameController.text.isNotEmpty
                                                ? _nameController.text
                                                : 'U')[0]
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 40,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              if (!_isGooglePhoto)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .scaffoldBackgroundColor,
                                        width: 3,
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt_outlined,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (!_isGooglePhoto)
                          Text(
                            context.tr(
                                'Ketuk foto untuk memilih gambar dari galeri',
                                'Tap the photo to choose an image from the gallery'),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                        labelText:
                            context.tr('Nama / Username', 'Name / Username'),
                        prefixIcon: const Icon(Icons.person)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                        labelText: context.tr('Nomor HP', 'Phone Number'),
                        prefixIcon: const Icon(Icons.phone)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    enabled: false,
                    decoration: InputDecoration(
                        labelText: context.tr('Email (tidak bisa diubah)',
                            'Email (cannot be changed)'),
                        prefixIcon: const Icon(Icons.email)),
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
                          : Text(
                              context.tr('Simpan Perubahan', 'Save Changes')),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Change Password Request
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.lock_reset,
                          color: AppTheme.infoColor),
                      title:
                          Text(context.tr('Ubah Password', 'Change Password')),
                      subtitle: Text(context.tr(
                          'Kirim email reset password langsung ke akun Anda',
                          'Send a password reset email directly to your account')),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _sendResetPasswordEmail,
                    ),
                  ),

                  const SizedBox(height: 8),
                  Card(
                    color: AppTheme.dangerColor.withValues(alpha: 0.05),
                    child: ListTile(
                      leading:
                          const Icon(Icons.logout, color: AppTheme.dangerColor),
                      title: const Text('Keluar',
                          style: TextStyle(color: AppTheme.dangerColor)),
                      onTap: () async {
                        final authProvider = context.read<AuthProvider>();
                        await authProvider.logout();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/home', (r) => false);
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
