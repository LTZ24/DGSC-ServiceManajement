import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/backend_service.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/app_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerSettingsScreen extends StatefulWidget {
  const CustomerSettingsScreen({super.key});

  @override
  State<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends State<CustomerSettingsScreen> {
  PermissionStatus? _notificationStatus;
  static const String _developerUrl = 'https://github.com/LTZ24';

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
  }

  Future<void> _loadNotificationStatus() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() => _notificationStatus = status);
    }
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (!mounted) return;

    final role = context.read<AuthProvider>().profile?['role']?.toString();

    setState(() => _notificationStatus = status);
    if (status.isGranted) {
      final userId = BackendService.currentUser?.uid;
      if (userId != null && userId.isNotEmpty) {
        await PushNotificationService.markPermissionPromptHandled(userId);
      }
      await PushNotificationService.syncTopicSubscriptions(
        userId: userId,
        role: role,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              context.tr('Notifikasi diaktifkan ✓', 'Notifications enabled ✓')),
          backgroundColor: AppTheme.successColor));
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr(
              'Izin notifikasi ditolak', 'Notification permission denied'))));
    }
  }

  Future<void> _openDeveloperLink() async {
    final uri = Uri.parse(_developerUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Tidak bisa membuka link developer.', 'Could not open developer link.')),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final authProvider = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Pengaturan', 'Settings'))),
      drawer: const AppDrawer(isAdmin: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Tampilan ──────────────────────────────────────────
          _sectionTitle(context, context.tr('Tampilan', 'Appearance')),
          _settingsCard(
            child: SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              secondary: Icon(
                themeProvider.isDark ? Icons.dark_mode : Icons.light_mode,
                color: AppTheme.primaryColor,
              ),
              title: Text(context.tr('Mode Gelap', 'Dark Mode')),
              subtitle: Text(
                  themeProvider.isDark
                      ? context.tr('Aktif', 'Enabled')
                      : context.tr('Nonaktif', 'Disabled'),
                  style: const TextStyle(fontSize: 12)),
              value: themeProvider.isDark,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ),
          const SizedBox(height: 12),
          _settingsCard(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const Icon(Icons.language, color: AppTheme.primaryColor),
              title: Text(context.tr('Bahasa', 'Language')),
              subtitle: Text(
                localeProvider.isEnglish ? 'English' : 'Bahasa Indonesia',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: localeProvider.languageCode,
                  onChanged: (value) {
                    if (value != null) {
                      localeProvider.setLocale(value);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'id', child: Text('Indonesia')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                ),
              ),
            ),
          ),

          // ── Notifikasi ────────────────────────────────────────
          const SizedBox(height: 20),
          _sectionTitle(context, context.tr('Notifikasi', 'Notifications')),
          _settingsCard(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined,
                  color: AppTheme.infoColor),
              title: Text(context.tr('Notifikasi Push', 'Push Notifications')),
              subtitle: Text(
                  context.tr('Izinkan notifikasi dari aplikasi ini',
                      'Allow notifications from this application'),
                  style: const TextStyle(fontSize: 12)),
              trailing: _notificationStatus == null
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _notificationStatus!.isGranted
                      ? const Icon(Icons.check_circle,
                          color: AppTheme.successColor)
                      : ElevatedButton(
                          onPressed: _requestNotificationPermission,
                          child: Text(_notificationStatus!.isPermanentlyDenied
                              ? context.tr('Buka', 'Open')
                              : context.tr('Aktifkan', 'Enable')),
                        ),
            ),
          ),

          // ── Info Aplikasi ─────────────────────────────────────
          const SizedBox(height: 20),
          _sectionTitle(context, context.tr('Tentang Aplikasi', 'About App')),
          _settingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_android,
                      color: AppTheme.primaryColor),
                  title: Text(context.tr(
                      'DigiTech Service Center', 'DigiTech Service Center')),
                  subtitle: Text(
                      context.tr('Aplikasi manajemen servis perangkat digital',
                          'Digital device service management application'),
                      style: TextStyle(fontSize: 12)),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline,
                      color: AppTheme.primaryColor),
                  title: Text(context.tr('Versi Aplikasi', 'App Version')),
                  trailing: const Text('1.0.1',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: const Icon(Icons.code, color: AppTheme.primaryColor),
                  title: Text(context.tr('Developer', 'Developer')),
                  subtitle: const Text('github.com/LTZ24'),
                  trailing: const Icon(Icons.open_in_new,
                      size: 16, color: Colors.grey),
                  onTap: _openDeveloperLink,
                ),
                ListTile(
                  leading: Icon(Icons.storage, color: AppTheme.primaryColor),
                  title:
                    Text(context.tr('Server', 'Server')),
                  subtitle: Text(
                    context.tr('Supabase PostgreSQL', 'Supabase PostgreSQL')),
                  trailing: const Icon(Icons.cloud_done,
                      color: AppTheme.successColor),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _settingsCard(
            child: ListTile(
              leading: const Icon(Icons.cleaning_services, color: Colors.grey),
              title: Text(context.tr('Bersihkan Cache', 'Clear Cache')),
              trailing: TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(context.tr(
                            'Cache berhasil dibersihkan',
                            'Cache cleared successfully')))),
                child: Text(context.tr('Bersihkan', 'Clear')),
              ),
            ),
          ),

          // ── Keluar ────────────────────────────────────────────
          const SizedBox(height: 20),
          _settingsCard(
            color: AppTheme.dangerColor.withValues(alpha: 0.05),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.dangerColor),
              title: Text(context.tr('Keluar', 'Logout'),
                  style: TextStyle(color: AppTheme.dangerColor)),
              onTap: () async {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/home', (r) => false);
                }
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _settingsCard({required Widget child, Color? color}) {
    return Card(
      color: color,
      margin: EdgeInsets.zero,
      child: child,
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}
