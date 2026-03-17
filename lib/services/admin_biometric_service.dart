import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AdminBiometricService {
  static const _enabledKey = 'admin_biometric_enabled';
  static const _refreshTokenKey = 'admin_biometric_refresh_token';
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
    return await _storage.read(key: _enabledKey) == 'true';
  }

  static Future<String?> getStoredAdminUid() {
    return _storage.read(key: _adminUidKey);
  }

  static Future<bool> canUseBiometricLogin() async {
    final supported = await isSupportedOnDevice();
    if (!supported) return false;
    final enabled = await isEnabled();
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    return enabled && refreshToken != null && refreshToken.isNotEmpty;
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

    final session = supabase.Supabase.instance.client.auth.currentSession;
    final refreshToken = session?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return;

    await _storage.write(key: _enabledKey, value: 'true');
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _adminUidKey, value: uid);
  }

  static Future<void> disable() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _adminUidKey);
  }

  static Future<bool> authenticate({String? reason, bool requireEnabled = true}) async {
    try {
      // When enabling biometrics, we must allow prompting even if the
      // feature isn't enabled yet (no stored refresh token).
      if (!await _canPromptForBiometrics()) return false;
      if (requireEnabled && !await canUseBiometricLogin()) return false;
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
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response =
          await supabase.Supabase.instance.client.auth.setSession(refreshToken);
      return response.session != null;
    } catch (_) {
      return false;
    }
  }
}
