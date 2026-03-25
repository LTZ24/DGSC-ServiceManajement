 import 'package:flutter/material.dart';
import '../services/backend_types.dart';
import '../services/backend_service.dart';
import '../services/app_lock_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _profile;
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => BackendService.currentUser != null;
  bool get isAdmin => _profile?['role'] == 'admin';
  bool get isCustomer => _profile?['role'] == 'customer';
  String? get error => _error;
  Map<String, dynamic>? get profile => _profile;
  User? get currentUser => BackendService.currentUser;

  /// Check if user is already authenticated (e.g. on app start)
  Future<bool> checkAuth() async {
    final user = BackendService.currentUser;
    if (user == null) return false;

    _isLoading = true;
    notifyListeners();

    _profile = await _loadProfileWithRetry(user.uid);

    final role = _profile?['role']?.toString();
    if (role != null && role.isNotEmpty) {
      await AppLockService.syncCurrentRole(role);
    }

    _isLoading = false;
    notifyListeners();
    return _profile != null;
  }

  /// Login with email + password via Supabase Auth
  Future<bool> login(
    String identifier,
    String password, {
    String? requiredRole,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await BackendService.signIn(identifier, password);
      final current = BackendService.currentUser;
      if (current == null) {
        _error = 'Sesi login tidak valid.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final uid = current.uid;
      _profile = await _loadProfileWithRetry(uid);

      final role = _profile?['role']?.toString();
      if (role != null && role.isNotEmpty) {
        await AppLockService.syncCurrentRole(role);
      }

      if (_profile == null) {
        await BackendService.signOut();
        _error = 'Profil akun tidak ditemukan.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (requiredRole != null && _profile?['role'] != requiredRole) {
        await BackendService.signOut();
        _profile = null;
        _error = requiredRole == 'admin'
            ? 'Akun ini tidak memiliki akses admin.'
            : 'Akun ini tidak memiliki akses customer.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();
      return _profile != null;
    } on BackendException catch (e) {
      _error = _mapLoginError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Login gagal. Periksa koneksi internet.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Register a new customer account
  Future<bool> register({
    required String username,
    required String email,
    required String name,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final hadActiveSession = BackendService.currentUser != null;
      await BackendService.register(
        email: email,
        password: password,
        username: username,
        phone: phone,
        role: 'customer',
      );

      if (!hadActiveSession) {
        await BackendService.signOut();
        _profile = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final currentUser = BackendService.currentUser;
      if (currentUser == null) {
        _error = 'Registrasi berhasil. Silakan login dengan akun baru Anda.';
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final uid = currentUser.uid;
      _profile = await _loadProfileWithRetry(uid);
      _isLoading = false;
      notifyListeners();
      return _profile != null;
    } on BackendException catch (e) {
      _error = _mapRegisterError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Registrasi gagal. Periksa koneksi internet.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await BackendService.signInWithGoogle();
      final currentUser = BackendService.currentUser;
      if (currentUser == null) {
        _error = 'Login Google dibatalkan atau belum selesai.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _profile = await _loadProfileWithRetry(currentUser.uid);

      final role = _profile?['role']?.toString();
      if (role != null && role.isNotEmpty) {
        await AppLockService.syncCurrentRole(role);
      }
      if (_profile == null) {
        await BackendService.signOut();
        _error = 'Profil akun Google belum siap. Silakan coba lagi.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (_profile?['role'] == 'admin') {
        await BackendService.signOut();
        _profile = null;
        _error = 'Login Google hanya tersedia untuk customer.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();
      return _profile != null;
    } on BackendException catch (e) {
      _error = _mapGoogleError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Login Google gagal. Coba lagi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout from Supabase Auth — clear state instantly, sign out in background
  Future<void> logout() async {
    await AppLockService.clearSessionState();
    await BackendService.signOut();
    _profile = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setError(String? message) {
    _error = message;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> _loadProfileWithRetry(String uid) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final profile = await BackendService.getUserProfile(uid);
      if (profile != null) return profile;
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    return null;
  }

  Future<void> refreshProfile() async {
    final user = BackendService.currentUser;
    if (user == null) return;
    _profile = await _loadProfileWithRetry(user.uid);
    notifyListeners();
  }

  String _mapLoginError(BackendException error) {
    final code = error.code;
    final message = error.message.toLowerCase();

    if (message.contains('email not confirmed')) {
      return 'Email belum diverifikasi. Cek inbox Anda sebelum login.';
    }

    if (message.contains('invalid login credentials') ||
        message.contains('invalid credentials') ||
        message.contains('akun dengan email, username, atau nomor hp')) {
      return 'Email, username, nomor HP, atau password salah.';
    }

    switch (code) {
      case 'user-not-found':
      case 'invalid_credentials':
        return 'Email, username, nomor HP, atau password salah.';
      case 'wrong-password':
        return 'Password salah.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'network_error':
        return 'Koneksi internet bermasalah. Coba lagi.';
      case 'auth_error':
        return 'Proses autentikasi gagal. Coba lagi.';
      default:
        return 'Terjadi kesalahan: ${error.message}';
    }
  }

  String _mapRegisterError(BackendException error) {
    final code = error.code;
    final message = error.message.toLowerCase();

    if (message.contains('already registered') ||
        message.contains('already been registered') ||
        message.contains('email_exists')) {
      return 'Email sudah digunakan.';
    }

    if (message.contains('duplicate key') && message.contains('username')) {
      return 'Username sudah digunakan.';
    }

    if (message.contains('duplicate key') && message.contains('phone')) {
      return 'Nomor HP sudah digunakan.';
    }

    if (message.contains('password should be at least') ||
        message.contains('weak password')) {
      return 'Password terlalu lemah (min. 6 karakter).';
    }

    switch (code) {
      case 'email-already-in-use':
      case 'email_exists':
        return 'Email sudah digunakan.';
      case 'weak-password':
        return 'Password terlalu lemah (min. 6 karakter).';
      case 'network_error':
        return 'Koneksi internet bermasalah. Coba lagi.';
      case 'register_error':
        return 'Registrasi gagal. Periksa koneksi internet.';
      default:
        return error.message.isNotEmpty
            ? error.message
            : 'Registrasi gagal. Silakan coba lagi.';
    }
  }

  String _mapGoogleError(BackendException error) {
    final code = error.code;
    switch (code) {
      case 'access_denied':
        return 'Akses login Google ditolak.';
      case 'google_cancelled':
        return 'Login Google dibatalkan.';
      case 'google_config':
        return 'Konfigurasi Google Sign-In belum lengkap.';
      case 'google_no_token':
        return 'Token Google tidak tersedia. Coba lagi.';
      case 'network_error':
        return 'Koneksi internet bermasalah. Coba lagi.';
      case 'server_error':
        return 'Konfigurasi login Google di server belum benar.';
      case 'auth_error':
        return 'Proses autentikasi gagal. Coba lagi.';
      default:
        return error.message.isNotEmpty
            ? error.message
            : 'Login Google gagal. Coba lagi.';
    }
  }
}
