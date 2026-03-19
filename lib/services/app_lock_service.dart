import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppLockService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _enabledKey = 'app_lock_enabled';
  static const String _pinKey = 'app_lock_pin';
  static const String _lastActiveKey = 'app_lock_last_active';

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

  static Future<bool> isEnabled() async {
    return await _storage.read(key: _enabledKey) == 'true';
  }

  static Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _storage.write(key: _enabledKey, value: 'true');
    } else {
      await _storage.delete(key: _enabledKey);
      await _storage.delete(key: _pinKey);
    }
  }

  static Future<String?> getPin() async {
    return await _storage.read(key: _pinKey);
  }

  static Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  static Future<void> recordActiveTime() async {
    await _storage.write(
      key: _lastActiveKey,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }
  
  static Future<void> clearActiveTime() async {
    await _storage.delete(key: _lastActiveKey);
  }

  static Future<bool> shouldLock() async {
    final enabled = await isEnabled();
    if (!enabled) return false;

    final lastActiveStr = await _storage.read(key: _lastActiveKey);
    if (lastActiveStr == null) return true; // Lock on cold start if enabled

    final lastActiveInfo = int.tryParse(lastActiveStr);
    if (lastActiveInfo == null) return true;

    final lastActive = DateTime.fromMillisecondsSinceEpoch(lastActiveInfo);
    final diff = DateTime.now().difference(lastActive).inMinutes;

    return diff >= 5;
  }

  static Future<bool> authenticateBiometric() async {
    try {
      if (!await isBiometricSupported()) return false;
      return await _localAuth.authenticate(
        localizedReason: 'Gunakan Face ID / Sidik Jari untuk membuka layar',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
