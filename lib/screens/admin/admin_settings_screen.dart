import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/backend_types.dart';
import '../../services/backend_service.dart';

import 'admin_profile_screen.dart';
import '../app_lock/app_lock_settings_screen.dart';
import '../../widgets/app_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  static const String _developerUrl = 'https://github.com/LTZ24';

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
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = BackendService.currentUser?.uid;
    if (uid != null) {
      _profile = await BackendService.getUserProfile(uid);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showCreateAdminDialog() async {
    final formKey = GlobalKey<FormState>();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var isLoading = false;
    var obscurePassword = true;
    var obscureConfirm = true;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            title: Text(context.tr('Tambah Akun Admin', 'Add Admin Account')),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.tr(
                            'Buat akun admin baru yang dapat login ke panel admin.',
                            'Create a new admin account that can sign in to the admin panel.'),
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      if (errorText != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  AppTheme.dangerColor.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            errorText!,
                            style: const TextStyle(
                              color: AppTheme.dangerColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: usernameCtrl,
                        decoration: InputDecoration(
                          labelText:
                              context.tr('Username Admin', 'Admin Username'),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (value) => value == null ||
                                value.trim().isEmpty
                            ? context.tr(
                                'Username wajib diisi', 'Username is required')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: context.tr('Email', 'Email'),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr(
                                'Email wajib diisi', 'Email is required');
                          }
                          if (!value.contains('@')) {
                            return context.tr('Format email tidak valid',
                                'Invalid email format');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: context.tr('Nomor HP', 'Phone Number'),
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: context.tr('Password', 'Password'),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setModalState(
                              () => obscurePassword = !obscurePassword,
                            ),
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return context.tr(
                                'Password wajib diisi', 'Password is required');
                          }
                          if (value.length < 6) {
                            return context.tr('Password minimal 6 karakter',
                                'Password must be at least 6 characters');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmCtrl,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: context.tr(
                              'Konfirmasi Password', 'Confirm Password'),
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          suffixIcon: IconButton(
                            onPressed: () => setModalState(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return context.tr('Konfirmasi password wajib diisi',
                                'Password confirmation is required');
                          }
                          if (value != passwordCtrl.text) {
                            return context.tr('Konfirmasi password tidak cocok',
                                'Password confirmation does not match');
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: Text(context.tr('Batal', 'Cancel')),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() {
                          isLoading = true;
                          errorText = null;
                        });
                        try {
                          await BackendService.createAdminAccount(
                            email: emailCtrl.text.trim(),
                            password: passwordCtrl.text,
                            username: usernameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                          );
                          if (!mounted || !ctx.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Akun admin berhasil ditambahkan'),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        } on BackendException catch (e) {
                          setModalState(() {
                            isLoading = false;
                            errorText = e.message;
                          });
                        } catch (_) {
                          setModalState(() {
                            isLoading = false;
                            errorText = context.tr('Gagal membuat akun admin.',
                                'Failed to create admin account.');
                          });
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(context.tr('Tambah akun', 'Add account')),
              ),
            ],
          ),
        );
      },
    );

    usernameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    passwordCtrl.dispose();
    confirmCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = context.read<AuthProvider>();

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final username = _profile?['username'] as String? ??
        BackendService.currentUser?.email ??
        context.tr('Admin', 'Admin');
    final email = _profile?['email'] as String? ??
        BackendService.currentUser?.email ??
        '';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Pengaturan Admin', 'Admin Settings')),
      ),
      drawer: const AppDrawer(isAdmin: true),
      body: RefreshIndicator.adaptive(
        onRefresh: _loadProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
          // ── Akun ─────────────────────────────────────────────────
          _sectionHeader(context, context.tr('Akun', 'Account')),
          _settingsCard(
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
                );
              },
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  username[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              title: Text(
                username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(email),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 12),
          _settingsCard(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: const Icon(Icons.lock_outline, color: AppTheme.primaryColor),
              ),
              title: Text(context.tr('App Lock & Keamanan', 'App Lock & Security')),
              subtitle: Text(context.tr(
                'Kelola PIN, biometrik, dan keamanan aplikasi',
                'Manage app PIN, biometrics, and security',
              )),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppLockSettingsScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _settingsCard(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const CircleAvatar(
                backgroundColor: Color(0x141D4ED8),
                child: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: AppTheme.primaryColor,
                ),
              ),
              title: Text(context.tr('Buat Akun Admin', 'Create Admin Account')),
              subtitle: Text(context.tr(
                'Tambahkan admin baru untuk panel pengelolaan.',
                'Add a new admin for the management panel.',
              )),
              trailing: ElevatedButton.icon(
                onPressed: _showCreateAdminDialog,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  minimumSize: const Size(0, 46),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(context.tr('Buat akun', 'Create account')),
              ),
            ),
          ),

          // ── Tampilan ──────────────────────────────────────────────
          const SizedBox(height: 20),
          _sectionHeader(context, context.tr('Tampilan', 'Appearance')),
          _settingsCard(
            child: SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              secondary: Icon(
                  themeProvider.isDark ? Icons.dark_mode : Icons.light_mode),
              title: Text(context.tr('Mode Gelap', 'Dark Mode')),
              subtitle: Text(themeProvider.isDark
                  ? context.tr('Aktif', 'Enabled')
                  : context.tr('Nonaktif', 'Disabled')),
              value: themeProvider.isDark,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ),
          const SizedBox(height: 12),
          _settingsCard(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.language, color: AppTheme.primaryColor),
              title: Text(context.tr('Bahasa', 'Language')),
              subtitle: Text(
                context.watch<LocaleProvider>().isEnglish
                    ? 'English'
                    : 'Bahasa Indonesia',
              ),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: context.watch<LocaleProvider>().languageCode,
                  onChanged: (value) {
                    if (value != null) {
                      context.read<LocaleProvider>().setLocale(value);
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
          _sectionHeader(
              context, context.tr('Data Diagnosis', 'Diagnosis Data')),
          _settingsCard(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.dataset_linked_outlined,
                  color: AppTheme.primaryColor),
              title: Text(
                  context.tr('Edit Data Diagnosis', 'Edit Diagnosis Data')),
              subtitle: Text(context.tr(
                  'Kelola JSON diagnosis, simpan draft, dan publish ke semua user',
                  'Manage diagnosis JSON, save drafts, and publish to all users')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.pushNamed(context, '/admin/diagnosis-editor'),
            ),
          ),

          // ── Info Aplikasi ─────────────────────────────────────────
          const SizedBox(height: 20),
          _sectionHeader(context, context.tr('Tentang Aplikasi', 'About App')),
          _settingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_android,
                      color: AppTheme.primaryColor),
                  title: const Text('DigiTech Service Center'),
                  subtitle: Text(context.tr('Sistem Manajemen Servis Digital',
                      'Digital Service Management System')),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline,
                      color: AppTheme.primaryColor),
                  title: Text(context.tr('Versi Aplikasi', 'App Version')),
                  trailing: const Text('1.0.2',
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

          // ── Log ────────────────────────────────────────────────
          const SizedBox(height: 20),
          _settingsCard(
            child: ListTile(
              leading: const Icon(Icons.receipt_long, color: AppTheme.primaryColor),
              title: Text(context.tr('Log', 'Log')),
              subtitle: Text(context.tr('Lihat log aplikasi dan error terbaru', 'View application logs and recent errors')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/admin/logs'),
            ),
          ),

          // ── Logout ────────────────────────────────────────────────
          const SizedBox(height: 20),
          _settingsCard(
            color: AppTheme.dangerColor.withValues(alpha: 0.05),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.dangerColor),
              title: Text(context.tr('Keluar', 'Logout'),
                  style: TextStyle(color: AppTheme.dangerColor)),
              subtitle: Text(context.tr(
                  'Keluar dari akun admin', 'Sign out from the admin account')),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title:
                        Text(context.tr('Konfirmasi Keluar', 'Confirm Logout')),
                    content: Text(context.tr(
                        'Yakin ingin keluar dari akun admin?',
                        'Are you sure you want to sign out from the admin account?')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(context.tr('Batal', 'Cancel')),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.dangerColor),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(context.tr('Keluar', 'Logout')),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/home', (r) => false);
                  }
                }
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
