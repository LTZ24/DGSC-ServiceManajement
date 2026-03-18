import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_biometric_service.dart';
import '../../services/backend_types.dart';
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
  bool _biometricSupported = false;
  bool _securityEnabled = false;
  static const String _developerUrl = 'https://github.com/LTZ24';

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
    _loadSecurityState();
  }

  Future<void> _loadSecurityState() async {
    final supported = await AdminBiometricService.isSupportedOnDevice();
    final enabled = await AdminBiometricService.isEnabledForRole('customer');
    if (!mounted) return;
    setState(() {
      _biometricSupported = supported;
      _securityEnabled = enabled;
    });
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
    final errorText = context.tr(
      'Tidak bisa membuka link developer.',
      'Could not open developer link.',
    );
    final uri = Uri.parse(_developerUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorText),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  Future<void> _toggleSecurity(bool enable) async {
    final reasonText = context.tr(
      'Verifikasi sidik jari Anda untuk mengaktifkan keamanan aplikasi.',
      'Verify your fingerprint to enable app security.',
    );
    final activationCancelledText = context.tr(
      'Aktivasi keamanan dibatalkan.',
      'Security activation canceled.',
    );
    final enabledText = context.tr(
      'Keamanan aplikasi aktif.',
      'App security is enabled.',
    );
    final failedText = context.tr(
      'Gagal mengaktifkan keamanan.',
      'Failed to enable security.',
    );
    final disabledText = context.tr(
      'Keamanan aplikasi dinonaktifkan.',
      'App security disabled.',
    );

    if (enable) {
      final password = await _showPasswordConfirmationDialog();
      if (password == null || password.isEmpty) {
        if (!mounted) return;
        setState(() => _securityEnabled = false);
        return;
      }

      try {
        await BackendService.verifyCurrentPassword(password);
        if (!mounted) return;
        final authenticated = await AdminBiometricService.authenticate(
          reason: reasonText,
          requireEnabled: false,
        );
        if (!mounted) return;

        if (!authenticated) {
          if (!mounted) return;
          setState(() => _securityEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(activationCancelledText),
              backgroundColor: AppTheme.warningColor,
            ),
          );
          return;
        }

        await AdminBiometricService.enableForCustomer();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabledText),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } on BackendException catch (e) {
        if (!mounted) return;
        setState(() => _securityEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      } catch (_) {
        if (!mounted) return;
        setState(() => _securityEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failedText),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
      return;
    }

    await AdminBiometricService.disableForRole('customer');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(disabledText),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<String?> _showPasswordConfirmationDialog() async {
    final passwordCtrl = TextEditingController();
    var obscurePassword = true;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(context.tr('Konfirmasi Password', 'Confirm Password')),
          content: TextField(
            controller: passwordCtrl,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: context.tr('Password Customer', 'Customer Password'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setModalState(
                  () => obscurePassword = !obscurePassword,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('Batal', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, passwordCtrl.text),
              child: Text(context.tr('Konfirmasi', 'Confirm')),
            ),
          ],
        ),
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

          if (_biometricSupported) ...[
            const SizedBox(height: 12),
            _settingsCard(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  backgroundColor: _securityEnabled
                      ? AppTheme.successColor.withValues(alpha: 0.14)
                      : AppTheme.primaryColor.withValues(alpha: 0.10),
                  child: Icon(
                    Icons.fingerprint,
                    color: _securityEnabled
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                  ),
                ),
                title: Text(context.tr(
                    'Keamanan Sidik Jari',
                    'Fingerprint Security')),
                subtitle: Text(_securityEnabled
                    ? context.tr('Aktif untuk lock aplikasi customer.',
                        'Enabled for customer app lock.')
                    : context.tr('Nonaktif.', 'Disabled.')),
                trailing: Switch(
                  value: _securityEnabled,
                  onChanged: (value) {
                    setState(() => _securityEnabled = value);
                    _toggleSecurity(value);
                  },
                ),
              ),
            ),
          ],

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
                      context, '/login', (r) => false,
                      arguments: {'role': 'customer'});
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
