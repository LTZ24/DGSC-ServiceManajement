import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/firebase_db_service.dart';
import '../../widgets/app_drawer.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseDbService.currentUser?.uid;
    if (uid != null) {
      _profile = await FirebaseDbService.getUserProfile(uid);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = context.read<AuthProvider>();

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final username = _profile?['username'] as String? ??
        FirebaseDbService.currentUser?.email ?? 'Admin';
    final email = _profile?['email'] as String? ??
        FirebaseDbService.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Admin')),
      drawer: const AppDrawer(isAdmin: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Akun ─────────────────────────────────────────────────
          _sectionHeader(context, 'Akun'),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  username[0].toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(email),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Admin',
                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
              ),
            ),
          ),

          // ── Permintaan Ubah Password ──────────────────────────────
          const SizedBox(height: 20),
          _sectionHeader(context, 'Permintaan Ubah Password'),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseDbService.pendingPasswordRequestsStream(),
            builder: (context, snapshot) {
              final requests = snapshot.data?.docs ?? [];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                    child: Padding(padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2))));
              }
              if (requests.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.check_circle_outline, color: AppTheme.successColor),
                    title: Text('Tidak ada permintaan pending'),
                    subtitle: Text('Semua sudah ditangani', style: TextStyle(fontSize: 12)),
                  ),
                );
              }
              return Card(
                child: Column(
                  children: requests.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final reqEmail = data['email'] as String? ?? '';
                    final reqUser = data['username'] as String? ?? reqEmail;
                    return Column(children: [
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x14F59E0B),
                          child: Icon(Icons.lock_reset, color: AppTheme.warningColor),
                        ),
                        title: Text(reqUser,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(reqEmail, style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
                              onPressed: () async {
                                await FirebaseDbService.reviewPasswordRequest(
                                    doc.id, 'rejected',
                                    FirebaseDbService.currentUser?.uid ?? '');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Ditolak')));
                                }
                              },
                              child: const Text('Tolak'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  await FirebaseDbService.sendPasswordResetEmail(reqEmail);
                                  await FirebaseDbService.reviewPasswordRequest(
                                      doc.id, 'approved',
                                      FirebaseDbService.currentUser?.uid ?? '');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Disetujui! Email reset terkirim'),
                                            backgroundColor: AppTheme.successColor));
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text('Gagal: $e'),
                                        backgroundColor: AppTheme.dangerColor));
                                  }
                                }
                              },
                              child: const Text('Setujui'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ]);
                  }).toList(),
                ),
              );
            },
          ),

          // ── Tampilan ──────────────────────────────────────────────
          const SizedBox(height: 20),
          _sectionHeader(context, 'Tampilan'),
          Card(
            child: SwitchListTile(
              secondary: Icon(themeProvider.isDark ? Icons.dark_mode : Icons.light_mode),
              title: const Text('Mode Gelap'),
              subtitle: Text(themeProvider.isDark ? 'Aktif' : 'Nonaktif'),
              value: themeProvider.isDark,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ),

          // ── Notifikasi ────────────────────────────────────────────
          const SizedBox(height: 20),
          _sectionHeader(context, 'Notifikasi'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined, color: AppTheme.infoColor),
              title: const Text('Notifikasi Push'),
              subtitle: const Text('Izinkan notifikasi dari aplikasi ini'),
              trailing: ElevatedButton(
                onPressed: () async {
                  final status = await Permission.notification.request();
                  if (!context.mounted) return;
                  if (status.isGranted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifikasi diaktifkan ✓'),
                            backgroundColor: AppTheme.successColor));
                  } else if (status.isPermanentlyDenied) {
                    openAppSettings();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Izin notifikasi ditolak')));
                  }
                },
                child: const Text('Aktifkan'),
              ),
            ),
          ),

          // ── Info Aplikasi ─────────────────────────────────────────
          const SizedBox(height: 20),
          _sectionHeader(context, 'Tentang Aplikasi'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.phone_android, color: AppTheme.primaryColor),
                  title: Text('DigiTech Service Center'),
                  subtitle: Text('Sistem Manajemen Servis Digital'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline, color: AppTheme.primaryColor),
                  title: Text('Versi Aplikasi'),
                  trailing: Text('1.0.0', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code, color: AppTheme.primaryColor),
                  title: const Text('GitHub Developer'),
                  subtitle: const Text('github.com/LTZ24'),
                  trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('https://github.com/LTZ24'))),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.storage, color: AppTheme.primaryColor),
                  title: Text('Server / Backend'),
                  subtitle: Text('Firebase Firestore (Google Cloud)'),
                  trailing: Icon(Icons.cloud_done, color: AppTheme.successColor),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services, color: Colors.grey),
                  title: const Text('Bersihkan Cache'),
                  trailing: TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cache berhasil dibersihkan'))),
                    child: const Text('Bersihkan'),
                  ),
                ),
              ],
            ),
          ),

          // ── Logout ────────────────────────────────────────────────
          const SizedBox(height: 20),
          Card(
            color: AppTheme.dangerColor.withValues(alpha: 0.05),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.dangerColor),
              title: const Text('Keluar', style: TextStyle(color: AppTheme.dangerColor)),
              subtitle: const Text('Keluar dari akun admin'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Konfirmasi Keluar'),
                    content: const Text('Yakin ingin keluar dari akun admin?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Keluar'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}