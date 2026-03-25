import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/app_drawer.dart';
import '../app_lock/app_lock_settings_screen.dart';

class CustomerSettingsScreen extends StatelessWidget {
  const CustomerSettingsScreen({super.key});

  static const String _developerUrl = 'https://github.com/LTZ24';

  Future<void> _openDeveloperLink(BuildContext context) async {
    final uri = Uri.parse(_developerUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'Tidak bisa membuka link developer.',
            'Could not open developer link.',
          ),
        ),
        backgroundColor: AppTheme.dangerColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final authProvider = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Pengaturan', 'Settings'))),
      drawer: const AppDrawer(isAdmin: false),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          await context.read<AuthProvider>().refreshProfile();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
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
                style: const TextStyle(fontSize: 12),
              ),
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
          const SizedBox(height: 20),
          _sectionTitle(context, context.tr('Keamanan', 'Security')),
          _settingsCard(
            child: ListTile(
              leading:
                  const Icon(Icons.lock_outline, color: AppTheme.primaryColor),
              title: Text(context.tr('App Lock', 'App Lock')),
              subtitle: Text(
                context.tr(
                  'Kelola password, PIN, pola, biometrik, dan timeout App Lock.',
                  'Manage password, PIN, pattern, biometrics, and App Lock timeout.',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppLockSettingsScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle(context, context.tr('Tentang Aplikasi', 'About App')),
          _settingsCard(
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.phone_android, color: AppTheme.primaryColor),
                  title: Text(
                    context.tr(
                      'DigiTech Service Center',
                      'DigiTech Service Center',
                    ),
                  ),
                  subtitle: Text(
                    context.tr(
                      'Aplikasi manajemen servis perangkat digital',
                      'Digital device service management application',
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                  title: Text(context.tr('Versi Aplikasi', 'App Version')),
                  trailing: const Text(
                    '1.0.2',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.code, color: AppTheme.primaryColor),
                  title: Text(context.tr('Developer', 'Developer')),
                  subtitle: const Text('github.com/LTZ24'),
                  trailing:
                      const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                  onTap: () => _openDeveloperLink(context),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.storage, color: AppTheme.primaryColor),
                  title: Text(context.tr('Server', 'Server')),
                  subtitle: Text(
                    context.tr('Supabase PostgreSQL', 'Supabase PostgreSQL'),
                  ),
                  trailing: const Icon(
                    Icons.cloud_done,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _settingsCard(
            child: ListTile(
              leading:
                  const Icon(Icons.cleaning_services, color: Colors.grey),
              title: Text(context.tr('Bersihkan Cache', 'Clear Cache')),
              trailing: TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr(
                        'Cache berhasil dibersihkan',
                        'Cache cleared successfully',
                      ),
                    ),
                  ),
                ),
                child: Text(context.tr('Bersihkan', 'Clear')),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _settingsCard(
            color: AppTheme.dangerColor.withValues(alpha: 0.05),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.dangerColor),
              title: Text(
                context.tr('Keluar', 'Logout'),
                style: const TextStyle(color: AppTheme.dangerColor),
              ),
              onTap: () async {
                await authProvider.logout();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                  arguments: {'role': 'customer'},
                );
              },
            ),
          ),
            const SizedBox(height: 24),
          ],
        ),
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
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
