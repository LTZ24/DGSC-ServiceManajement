import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/theme.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/customer_dashboard.dart';
import 'services/admin_biometric_service.dart';
import 'services/backend_service.dart';
import 'providers/auth_provider.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  static const String _lastActiveKey = 'last_active_time';
  static const int _timeoutMinutes = 1;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final TextEditingController _unlockPasswordController =
      TextEditingController();
  StreamSubscription<AuthState>? _authSubscription;

  bool _isLocked = false;
  bool _isLoading = true;
  bool _unlocking = false;
  bool _biometricEnabledForAdmin = false;
  String? _role;
  String? _unlockError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _checkInitialAuth();
    });
    _checkInitialAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _unlockPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialAuth() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (!mounted) return;
      setState(() {
        _role = null;
        _isLocked = false;
        _isLoading = false;
      });
      return;
    }

    await _syncProviderProfile();

    final role = await _resolveRole();
    if (!mounted) return;

    if (role == null) {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      setState(() {
        _role = null;
        _isLocked = false;
        _isLoading = false;
      });
      return;
    }

    final biometricEnabled = role == 'admin'
        ? await AdminBiometricService.isEnabled()
        : false;

    if (role == 'admin' && biometricEnabled) {
      setState(() {
        _role = role;
        _isLocked = true;
        _biometricEnabledForAdmin = true;
      });
    } else {
      setState(() {
        _role = role;
        _isLocked = false;
        _biometricEnabledForAdmin = biometricEnabled;
      });
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<String?> _resolveRole() async {
    final providerRole = context.read<AuthProvider>().profile?['role']?.toString();
    if (providerRole != null && providerRole.isNotEmpty) {
      return providerRole;
    }

    final user = BackendService.currentUser;
    if (user == null) return null;
    final profile = await BackendService.getUserProfile(user.uid);
    return profile?['role']?.toString();
  }

  Future<void> _syncProviderProfile() async {
    try {
      await context.read<AuthProvider>().checkAuth();
    } catch (_) {}
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    final prefs = await SharedPreferences.getInstance();

    if (state == AppLifecycleState.paused) {
      await prefs.setInt(
        _lastActiveKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      return;
    }

    if (state != AppLifecycleState.resumed) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    await _syncProviderProfile();
    final role = _role ?? await _resolveRole();
    if (role != 'admin') return;

    final biometricEnabled = await AdminBiometricService.isEnabled();
    if (!biometricEnabled) {
      if (mounted) {
        setState(() {
          _biometricEnabledForAdmin = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _biometricEnabledForAdmin = true;
      });
    }

    final lastActive = prefs.getInt(_lastActiveKey);
    if (lastActive == null) return;

    final difference = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastActive))
        .inMinutes;

    if (difference >= _timeoutMinutes) {
      if (!mounted) return;
      setState(() {
        _isLocked = true;
      });
    }
  }

  Future<bool> _authenticateBiometric() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate =
          canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!canAuthenticate) return false;

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Gunakan sidik jari untuk membuka DGSC Service',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate && mounted) {
        setState(() {
          _isLocked = false;
          _unlockError = null;
        });
      }
      return didAuthenticate;
    } catch (_) {
      return false;
    }
  }

  Future<void> _unlockWithPassword() async {
    final password = _unlockPasswordController.text;
    if (password.isEmpty) {
      setState(() {
        _unlockError = 'Masukkan password admin.';
      });
      return;
    }

    setState(() {
      _unlocking = true;
      _unlockError = null;
    });

    try {
      await BackendService.verifyCurrentPassword(password);
      if (!mounted) return;
      setState(() {
        _isLocked = false;
        _unlocking = false;
        _unlockError = null;
      });
      _unlockPasswordController.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _unlocking = false;
        _unlockError = 'Password tidak valid.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const LoginScreen();
    }

    if (_isLocked && _role == 'admin') {
      final theme = Theme.of(context);
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.14),
                theme.scaffoldBackgroundColor,
              ],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              AppTheme.primaryColor.withValues(alpha: 0.15),
                          child: const Icon(Icons.lock_rounded,
                              color: AppTheme.primaryColor, size: 30),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Aplikasi Terkunci',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Konfirmasi password atau sidik jari untuk membuka aplikasi admin.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _unlockPasswordController,
                                obscureText: true,
                                enabled: !_unlocking,
                                onSubmitted: (_) => _unlockWithPassword(),
                                decoration: const InputDecoration(
                                  labelText: 'Password Admin',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                              ),
                            ),
                            if (_biometricEnabledForAdmin) ...[
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 52,
                                width: 52,
                                child: IconButton.filledTonal(
                                  onPressed: _unlocking
                                      ? null
                                      : () => _authenticateBiometric(),
                                  icon: const Icon(Icons.fingerprint),
                                  tooltip: 'Buka dengan Sidik Jari',
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_unlockError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _unlockError!,
                            style: const TextStyle(color: AppTheme.dangerColor),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _unlocking ? null : _unlockWithPassword,
                            child: _unlocking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Buka Kunci'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_role == 'admin') {
      return const AdminDashboardScreen();
    }

    return const CustomerDashboardScreen();
  }
}
