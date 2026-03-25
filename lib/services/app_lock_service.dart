import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'backend_service.dart';

class AppLockService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _currentRoleKey = 'app_lock_current_role';
  static const int defaultTimeoutSeconds = 300;
  static const List<int> supportedTimeoutSeconds = [
    30,
    60,
    120,
    300,
    600,
    1800,
  ];

  static String? _cachedRole;

  static String _enabledKey(String role) => 'app_lock_enabled_$role';
  static String _pinKey(String role) => 'app_lock_pin_$role';
  static String _patternKey(String role) => 'app_lock_pattern_$role';
  static String _methodKey(String role) => 'app_lock_method_$role';
  static String _biometricEnabledKey(String role) =>
      'app_lock_biometric_enabled_$role';
  static String _pendingBackgroundKey(String role) =>
      'app_lock_pending_background_$role';
  static String _lastActiveKey(String role) => 'app_lock_last_active_$role';
  static String _timeoutKey(String role) => 'app_lock_timeout_$role';

  static Future<String?> _resolveRole([String? role]) async {
    if (role != null && role.isNotEmpty) {
      _cachedRole = role;
      return role;
    }

    final cachedRole = _cachedRole;
    if (cachedRole != null && cachedRole.isNotEmpty) {
      return cachedRole;
    }

    final storedRole = await _storage.read(key: _currentRoleKey);
    if (storedRole != null && storedRole.isNotEmpty) {
      _cachedRole = storedRole;
      return storedRole;
    }

    final uid = BackendService.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;

    final profile = await BackendService.getUserProfile(uid);
    final resolved = profile?['role']?.toString();
    if (resolved != null && resolved.isNotEmpty) {
      _cachedRole = resolved;
      await _storage.write(key: _currentRoleKey, value: resolved);
      return resolved;
    }

    return null;
  }

  static Future<void> syncCurrentRole(String role) async {
    if (role.isEmpty) return;
    _cachedRole = role;
    await _storage.write(key: _currentRoleKey, value: role);
  }

  static Future<void> clearSessionState() async {
    final role = _cachedRole ?? await _storage.read(key: _currentRoleKey);
    if (role != null && role.isNotEmpty) {
      await _storage.delete(key: _lastActiveKey(role));
      await _storage.delete(key: _pendingBackgroundKey(role));
    }
    _cachedRole = null;
    await _storage.delete(key: _currentRoleKey);
  }

  static Future<bool> isBiometricSupported() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> isEnabled({String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return false;
    return await _storage.read(key: _enabledKey(resolvedRole)) == 'true';
  }

  static Future<void> setEnabled(bool enabled, {String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return;

    if (enabled) {
      await _storage.write(key: _enabledKey(resolvedRole), value: 'true');
      return;
    }

    await _storage.delete(key: _enabledKey(resolvedRole));
    await _storage.delete(key: _pinKey(resolvedRole));
    await _storage.delete(key: _patternKey(resolvedRole));
    await _storage.delete(key: _methodKey(resolvedRole));
    await _storage.delete(key: _biometricEnabledKey(resolvedRole));
    await _storage.delete(key: _pendingBackgroundKey(resolvedRole));
    await _storage.delete(key: _lastActiveKey(resolvedRole));
    await _storage.delete(key: _timeoutKey(resolvedRole));
  }

  static Future<String> getUnlockMethod({String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return 'password';

    final stored = await _storage.read(key: _methodKey(resolvedRole));
    if (stored == 'password' || stored == 'pin' || stored == 'pattern') {
      return stored!;
    }
    return 'password';
  }

  static Future<void> setUnlockMethod(String method, {String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return;
    if (method != 'password' && method != 'pin' && method != 'pattern') return;
    await _storage.write(key: _methodKey(resolvedRole), value: method);
  }

  static Future<bool> isBiometricEnabled({String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return false;
    return await _storage.read(key: _biometricEnabledKey(resolvedRole)) ==
        'true';
  }

  static Future<void> setBiometricEnabled(bool enabled, {String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return;

    if (enabled) {
      await _storage.write(
        key: _biometricEnabledKey(resolvedRole),
        value: 'true',
      );
      return;
    }

    await _storage.delete(key: _biometricEnabledKey(resolvedRole));
  }

  static Future<String?> getPin({String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return null;
    return await _storage.read(key: _pinKey(resolvedRole));
  }

  static Future<void> setPin(String pin, {String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return;
    await _storage.write(key: _pinKey(resolvedRole), value: pin);
  }

  static Future<String?> getPattern({String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return null;
    return await _storage.read(key: _patternKey(resolvedRole));
  }

  static Future<void> setPattern(String pattern, {String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return;
    await _storage.write(key: _patternKey(resolvedRole), value: pattern);
  }

  static Future<int> getLockTimeoutSeconds({String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return defaultTimeoutSeconds;

    final stored = int.tryParse(
      await _storage.read(key: _timeoutKey(resolvedRole)) ?? '',
    );
    if (stored != null && supportedTimeoutSeconds.contains(stored)) {
      return stored;
    }
    return defaultTimeoutSeconds;
  }

  static Future<void> setLockTimeoutSeconds(int seconds, {String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return;
    if (!supportedTimeoutSeconds.contains(seconds)) return;
    await _storage.write(key: _timeoutKey(resolvedRole), value: '$seconds');
  }

  static Future<void> recordActiveTime({String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return;

    await _storage.write(
      key: _lastActiveKey(resolvedRole),
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    await _storage.delete(key: _pendingBackgroundKey(resolvedRole));
  }

  static Future<void> clearActiveTime({String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return;
    await _storage.delete(key: _lastActiveKey(resolvedRole));
    await _storage.delete(key: _pendingBackgroundKey(resolvedRole));
  }

  static Future<void> markBackground({String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return;

    await _storage.write(key: _pendingBackgroundKey(resolvedRole), value: 'true');
    await _storage.write(
      key: _lastActiveKey(resolvedRole),
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  static Future<void> markForeground({String? role}) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return;
    await _storage.delete(key: _pendingBackgroundKey(resolvedRole));
  }

  static Future<bool> shouldLock({
    String? role,
    bool isColdStart = true,
  }) async {
    final resolvedRole = await _resolveRole(role);
    if (resolvedRole == null) return false;

    final values = await Future.wait<String?>([
      _storage.read(key: _enabledKey(resolvedRole)),
      _storage.read(key: _pendingBackgroundKey(resolvedRole)),
      _storage.read(key: _lastActiveKey(resolvedRole)),
      _storage.read(key: _timeoutKey(resolvedRole)),
    ]);

    final enabled = values[0] == 'true';
    if (!enabled) return false;

    final pendingBackground = values[1] == 'true';
    if (isColdStart && pendingBackground) {
      return true;
    }

    final lastActiveMillis = int.tryParse(values[2] ?? '');
    if (lastActiveMillis == null) return true;

    final timeout = int.tryParse(values[3] ?? '') ?? defaultTimeoutSeconds;
    final normalizedTimeout = supportedTimeoutSeconds.contains(timeout)
        ? timeout
        : defaultTimeoutSeconds;

    final lastActive = DateTime.fromMillisecondsSinceEpoch(lastActiveMillis);
    final diffSeconds = DateTime.now().difference(lastActive).inSeconds;
    return diffSeconds >= normalizedTimeout;
  }

  static Future<bool> authenticateBiometric() async {
    try {
      if (!await isBiometricSupported()) return false;
      await _localAuth.stopAuthentication();
      return await _localAuth.authenticate(
        localizedReason: 'Gunakan biometrik untuk membuka aplikasi',
        options: const AuthenticationOptions(
          biometricOnly: true,
          sensitiveTransaction: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
