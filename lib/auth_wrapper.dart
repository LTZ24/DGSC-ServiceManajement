import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/theme.dart';
import 'screens/home_screen.dart';
import 'screens/admin/admin_dashboard.dart';
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
  static const int _timeoutMinutes = 5;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final TextEditingController _unlockPasswordController =
      TextEditingController();
  StreamSubscription<AuthState>? _authSubscription;

  bool _isLocked = false;
  bool _isLoading = true;
  bool _unlocking = false;
  bool _securityEnabledForRole = false;
  bool _hasFingerprint = false;
  bool _hasFaceId = false;
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
        ? await AdminBiometricService.isEnabledForRole('admin')
        : await AdminBiometricService.isEnabledForRole('customer');

    await _refreshBiometricCapabilities();

    if (role == 'admin' && biometricEnabled) {
      setState(() {
        _role = role;
        _isLocked = true;
        _securityEnabledForRole = true;
      });
    } else if (role == 'customer' && biometricEnabled) {
      setState(() {
        _role = role;
        _isLocked = true;
        _securityEnabledForRole = true;
      });
    } else {
      setState(() {
        _role = role;
        _isLocked = false;
        _securityEnabledForRole = biometricEnabled;
      });
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _refreshBiometricCapabilities() async {
    try {
      final types = await _localAuth.getAvailableBiometrics();
      if (!mounted) return;
      final hasFingerprint = types.contains(BiometricType.fingerprint);
      final hasFace = types.contains(BiometricType.face) ||
          (!hasFingerprint &&
              (types.contains(BiometricType.strong) ||
                  types.contains(BiometricType.weak)));
      setState(() {
        _hasFingerprint = hasFingerprint;
        _hasFaceId = hasFace;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasFingerprint = false;
        _hasFaceId = false;
      });
    }
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
    if (role != 'admin' && role != 'customer') return;

    final biometricEnabled = await AdminBiometricService.isEnabledForRole(role!);
    if (!biometricEnabled) {
      if (mounted) {
        setState(() {
          _securityEnabledForRole = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _securityEnabledForRole = true;
      });
    }

    await _refreshBiometricCapabilities();

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

  Future<bool> _authenticateBiometric({String? preferred}) async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate =
          canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!canAuthenticate) return false;

      if (preferred == 'fingerprint' && !_hasFingerprint) return false;
      if (preferred == 'face' && !_hasFaceId) return false;

      final reason = preferred == 'face'
          ? 'Gunakan Face ID/Face Recognition untuk membuka DGSC Service'
          : preferred == 'fingerprint'
              ? 'Gunakan sidik jari untuk membuka DGSC Service'
              : 'Gunakan biometrik untuk membuka DGSC Service';

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
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
        _unlockError = 'Masukkan password.';
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
      return const HomeScreen();
    }

    if (_isLocked && (_role == 'admin' || _role == 'customer')) {
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
                          'Konfirmasi password atau biometrik untuk membuka aplikasi.',
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
                                decoration: InputDecoration(
                                  labelText: _role == 'admin'
                                      ? 'Password Admin'
                                      : 'Password Customer',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                              ),
                            ),
                            if (_securityEnabledForRole && _hasFingerprint) ...[
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 52,
                                width: 52,
                                child: IconButton.filledTonal(
                                  onPressed: _unlocking
                                      ? null
                                      : () => _authenticateBiometric(
                                            preferred: 'fingerprint',
                                          ),
                                  icon: const Icon(Icons.fingerprint),
                                  tooltip: 'Buka dengan Sidik Jari',
                                ),
                              ),
                            ],
                            if (_securityEnabledForRole && _hasFaceId) ...[
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 52,
                                width: 52,
                                child: IconButton.filledTonal(
                                  onPressed: _unlocking
                                      ? null
                                      : () => _authenticateBiometric(
                                            preferred: 'face',
                                          ),
                                  icon: const Icon(Icons.face_rounded),
                                  tooltip: 'Buka dengan Face ID',
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
