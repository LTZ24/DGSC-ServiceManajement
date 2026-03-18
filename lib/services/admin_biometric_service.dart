import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AdminBiometricService {
  static const _enabledAdminKey = 'security_enabled_admin';
  static const _enabledCustomerKey = 'security_enabled_customer';
  static const _adminUidKey = 'admin_biometric_admin_uid';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static final LocalAuthentication _localAuth = LocalAuthentication();

  static Future<bool> isSupportedOnDevice() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;
      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    return await isEnabledForRole('admin');
  }

  static Future<bool> isEnabledForRole(String role) async {
    final key = role == 'admin' ? _enabledAdminKey : _enabledCustomerKey;
    return await _storage.read(key: key) == 'true';
  }

  static Future<String?> getStoredAdminUid() {
    return _storage.read(key: _adminUidKey);
  }

  static Future<bool> canUseBiometricLogin() async {
    final supported = await isSupportedOnDevice();
    if (!supported) return false;
    return await isEnabled();
  }

  static Future<bool> _canPromptForBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;
      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> enableForCurrentAdmin({required String uid}) async {
    if (!await isSupportedOnDevice()) return;

    await _storage.write(key: _enabledAdminKey, value: 'true');
    await _storage.write(key: _adminUidKey, value: uid);
  }

  static Future<void> enableForCustomer() async {
    if (!await isSupportedOnDevice()) return;
    await _storage.write(key: _enabledCustomerKey, value: 'true');
  }

  static Future<void> disableForRole(String role) async {
    final key = role == 'admin' ? _enabledAdminKey : _enabledCustomerKey;
    await _storage.delete(key: key);
    if (role == 'admin') {
      await _storage.delete(key: _adminUidKey);
    }
  }

  static Future<void> disable() async {
    await _storage.delete(key: _enabledAdminKey);
    await _storage.delete(key: _enabledCustomerKey);
    await _storage.delete(key: _adminUidKey);
  }

  static Future<bool> authenticate({String? reason, bool requireEnabled = true}) async {
    try {
      // When enabling biometrics, we must allow prompting even if the
      // feature isn't enabled yet (no stored refresh token).
      if (!await _canPromptForBiometrics()) return false;
      if (requireEnabled && !await isEnabled()) return false;
      return await _localAuth.authenticate(
        localizedReason: reason ?? 'Sentuh sensor sidik jari untuk melanjutkan sebagai admin.',
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

  static Future<bool> restoreAdminSession() async {
    return false;
  }
}
