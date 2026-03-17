import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_biometric_service.dart';
import '../../services/app_log_service.dart';
import '../../services/backend_types.dart';
import '../../services/backend_service.dart';
import '../../services/push_notification_service.dart';
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
  PermissionStatus? _notificationStatus;
  bool _biometricEnabled = false;
  bool _biometricSupported = false;

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
    _loadNotificationStatus();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final supported = await AdminBiometricService.isSupportedOnDevice();
    final enabled = await AdminBiometricService.isEnabled();
    if (mounted) {
      setState(() {
        _biometricSupported = supported;
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _showToggleBiometricDialog(bool enable) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final enableReason = context.tr(
      'Verifikasi sidik jari Anda untuk mengaktifkan login cepat.',
      'Verify your fingerprint to enable quick login.',
    );
    final activationCancelled = context.tr(
      'Aktivasi sidik jari dibatalkan.',
      'Fingerprint activation canceled.',
    );
    final enabledSuccess = context.tr(
      'Login sidik jari berhasil diaktifkan.',
      'Fingerprint login enabled successfully.',
    );
    final disabledSuccess = context.tr(
      'Login sidik jari dinonaktifkan.',
      'Fingerprint login disabled.',
    );
    final errorPrefix = context.tr('Terjadi kesalahan', 'An error occurred');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Konfirmasi', 'Confirm')),
        content: Text(
          enable
              ? context.tr(
                  'Aktifkan login sidik jari?',
                  'Enable fingerprint login?',
                )
              : context.tr(
                  'Nonaktifkan login sidik jari?',
                  'Disable fingerprint login?',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Batal', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: enable ? AppTheme.successColor : AppTheme.dangerColor,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr(enable ? 'Aktifkan' : 'Nonaktifkan', enable ? 'Enable' : 'Disable')),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      // If user cancels, revert the switch state visually
      if (mounted) {
        setState(() {
          _biometricEnabled = !enable;
        });
      }
      return;
    }

    // If enabling, show password dialog first
    if (enable) {
      final password = await _showPasswordConfirmationDialog();
      if (password == null || password.isEmpty) {
        if (mounted) {
          setState(() {
            _biometricEnabled = false; // Revert switch
          });
        }
        return;
      }

      try {
        await BackendService.verifyCurrentPassword(password);

        final authenticated = await AdminBiometricService.authenticate(
          reason: enableReason,
          requireEnabled: false,
        );

        if (!authenticated) {
          await AppLogService.log(
            'Biometric activation cancelled/failed',
            level: 'WARN',
          );
          messenger.showSnackBar(SnackBar(
            content: Text(activationCancelled),
            backgroundColor: Colors.orange,
          ));
          if (mounted) {
            setState(() {
              _biometricEnabled = false; // Revert switch
            });
          }
          return;
        }

        await AdminBiometricService.enableForCurrentAdmin(uid: auth.currentUser!.uid);
        await AppLogService.log('Biometric login enabled');
        messenger.showSnackBar(SnackBar(
          content: Text(enabledSuccess),
          backgroundColor: Colors.green,
        ));
        // State is already set, no need to call setState again
      } on BackendException catch (e) {
        messenger.showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ));
        if (mounted) {
          setState(() {
            _biometricEnabled = false; // Revert switch on error
          });
        }
      } catch (e) {
        messenger.showSnackBar(SnackBar(
          content: Text('$errorPrefix: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
        if (mounted) {
          setState(() {
            _biometricEnabled = false; // Revert switch on error
          });
        }
      }
    } else {
      // Disabling
      await AdminBiometricService.disable();
      await AppLogService.log('Biometric login disabled');
      messenger.showSnackBar(SnackBar(
        content: Text(disabledSuccess),
        backgroundColor: Colors.green,
      ));
      // State is already set
    }
  }

  Future<String?> _showPasswordConfirmationDialog() async {
    final passwordCtrl = TextEditingController();
    var obscurePassword = true;

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(context.tr('Konfirmasi Password', 'Confirm Password')),
              content: TextField(
                controller: passwordCtrl,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: context.tr('Password Admin', 'Admin Password'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.tr('Batal', 'Cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx, passwordCtrl.text);
                  },
                  child: Text(context.tr('Konfirmasi', 'Confirm')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAdminResetPasswordDialog() async {
    final emailCtrl = TextEditingController(
      text: _profile?['email'] as String? ??
          BackendService.currentUser?.email ??
          '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Reset Password Admin', 'Reset Admin Password')),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: context.tr('Email akun admin', 'Admin account email'),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Batal', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Kirim Email', 'Send Email')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final email = emailCtrl.text.trim();
    emailCtrl.dispose();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            context.tr('Masukkan email yang valid.', 'Enter a valid email.')),
        backgroundColor: AppTheme.dangerColor,
      ));
      return;
    }
    try {
      await BackendService.sendPasswordResetEmail(email);
      await BackendService.savePasswordResetRole('admin');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr(
            'Email reset password telah dikirim ke $email.',
            'Password reset email has been sent to $email.')),
        backgroundColor: AppTheme.successColor,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr(
            'Gagal mengirim email reset.', 'Failed to send reset email.')),
        backgroundColor: AppTheme.dangerColor,
      ));
    }
  }

  Future<void> _loadProfile() async {
    final uid = BackendService.currentUser?.uid;
    if (uid != null) {
      _profile = await BackendService.getUserProfile(uid);
    }
    if (mounted) setState(() => _isLoading = false);
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

    setState(() => _notificationStatus = status);
    if (status.isGranted) {
      final userId = BackendService.currentUser?.uid;
      if (userId != null && userId.isNotEmpty) {
        await PushNotificationService.markPermissionPromptHandled(userId);
      }
      await PushNotificationService.syncTopicSubscriptions(
        userId: userId,
        role: 'admin',
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
      appBar:
          AppBar(title: Text(context.tr('Pengaturan Admin', 'Admin Settings'))),
      drawer: const AppDrawer(isAdmin: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Akun ─────────────────────────────────────────────────
          _sectionHeader(context, context.tr('Akun', 'Account')),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  username[0].toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
              ),
              title: Text(username,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(email),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(context.tr('Admin', 'Admin'),
                    style:
                        TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
              ),
            ),
          ),
          // Fingerprint activation tile (above Create Account)
          if (_biometricSupported) ...[
            const SizedBox(height: 12),
            _settingsCard(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  backgroundColor: _biometricEnabled
                      ? AppTheme.successColor.withValues(alpha: 0.12)
                      : AppTheme.primaryColor.withValues(alpha: 0.08),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    color: _biometricEnabled
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                  ),
                ),
                title:
                    Text(context.tr('Login Sidik Jari', 'Fingerprint Login')),
                subtitle: Text(_biometricEnabled
                    ? context.tr('Aktif — ketuk untuk menonaktifkan',
                        'Active — tap to disable')
                    : context.tr(
                        'Nonaktif — aktifkan untuk login tanpa password',
                        'Inactive — enable for passwordless login')),
                trailing: Switch(
                  value: _biometricEnabled,
                  onChanged: _biometricSupported
                      ? (bool value) {
                          setState(() => _biometricEnabled = value);
                          _showToggleBiometricDialog(value);
                        }
                      : null,
                ),
                onTap: () {
                  final nextValue = !_biometricEnabled;
                  setState(() => _biometricEnabled = nextValue);
                  _showToggleBiometricDialog(nextValue);
                },
              ),
            ),
          ],

          const SizedBox(height: 12),
          _settingsCard(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const CircleAvatar(
                backgroundColor: Color(0x141D4ED8),
                child: Icon(Icons.admin_panel_settings_outlined,
                    color: AppTheme.primaryColor),
              ),
              title:
                  Text(context.tr('Buat Akun Admin', 'Create Admin Account')),
              subtitle: Text(context.tr('Admin baru untuk panel pengelolaan.',
                  'New admin for the management panel.')),
              trailing: ElevatedButton.icon(
                onPressed: _showCreateAdminDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(context.tr('+', '+')),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _settingsCard(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const CircleAvatar(
                backgroundColor: Color(0x14F59E0B),
                child: Icon(Icons.lock_reset_rounded,
                    color: AppTheme.warningColor),
              ),
              title: Text(
                  context.tr('Reset Password Admin', 'Reset Admin Password')),
              subtitle: Text(context.tr(
                  'Kirim email reset password ke akun admin.',
                  'Send a password reset email to the admin account.')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showAdminResetPasswordDialog,
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
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

          // ── Notifikasi ────────────────────────────────────────────
          const SizedBox(height: 20),
          _sectionHeader(context, context.tr('Notifikasi', 'Notifications')),
          _settingsCard(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const Icon(Icons.notifications_outlined,
                  color: AppTheme.infoColor),
              title: Text(context.tr('Notifikasi Push', 'Push Notifications')),
              subtitle: Text(context.tr('Izinkan notifikasi dari aplikasi ini',
                  'Allow notifications from this application')),
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
              subtitle: Text(context.tr(
                  'view apps logs',
                  'view apps logs')),
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
