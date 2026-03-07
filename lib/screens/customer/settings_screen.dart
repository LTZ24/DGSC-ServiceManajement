import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/app_drawer.dart';

class CustomerSettingsScreen extends StatelessWidget {
  const CustomerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      drawer: const AppDrawer(isAdmin: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Tampilan ──────────────────────────────────────────
          _sectionTitle(context, 'Tampilan'),
          Card(
            child: SwitchListTile(
              secondary: Icon(
                themeProvider.isDark ? Icons.dark_mode : Icons.light_mode,
                color: AppTheme.primaryColor,
              ),
              title: const Text('Mode Gelap'),
              subtitle: Text(themeProvider.isDark ? 'Aktif' : 'Nonaktif',
                  style: const TextStyle(fontSize: 12)),
              value: themeProvider.isDark,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ),

          // ── Notifikasi ────────────────────────────────────────
          const SizedBox(height: 20),
          _sectionTitle(context, 'Notifikasi'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined, color: AppTheme.infoColor),
              title: const Text('Notifikasi Push'),
              subtitle: const Text('Izinkan notifikasi dari aplikasi ini',
                  style: TextStyle(fontSize: 12)),
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

          // ── Info Aplikasi ─────────────────────────────────────
          const SizedBox(height: 20),
          _sectionTitle(context, 'Tentang Aplikasi'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.phone_android, color: AppTheme.primaryColor),
                  title: Text('DigiTech Service Center'),
                  subtitle: Text('Aplikasi manajemen servis perangkat digital',
                      style: TextStyle(fontSize: 12)),
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
              ],
            ),
          ),

          // ── Keluar ────────────────────────────────────────────
          const SizedBox(height: 20),
          Card(
            color: AppTheme.dangerColor.withValues(alpha: 0.05),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.dangerColor),
              title: const Text('Keluar', style: TextStyle(color: AppTheme.dangerColor)),
              onTap: () async {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
                }
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}
