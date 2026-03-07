import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firebase_db_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _profile;
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => FirebaseDbService.currentUser != null;
  bool get isAdmin => _profile?['role'] == 'admin';
  bool get isCustomer => _profile?['role'] == 'customer';
  String? get error => _error;
  Map<String, dynamic>? get profile => _profile;
  User? get firebaseUser => FirebaseDbService.currentUser;

  /// Check if user is already authenticated (e.g. on app start)
  Future<bool> checkAuth() async {
    final user = FirebaseDbService.currentUser;
    if (user == null) return false;

    _isLoading = true;
    notifyListeners();

    _profile = await FirebaseDbService.getUserProfile(user.uid);

    _isLoading = false;
    notifyListeners();
    return _profile != null;
  }

  /// Login with email + password via Firebase Auth
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await FirebaseDbService.signIn(email, password);
      final uid = FirebaseDbService.currentUser!.uid;
      _profile = await FirebaseDbService.getUserProfile(uid);
      _isLoading = false;
      notifyListeners();
      return _profile != null;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e.code);
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
      await FirebaseDbService.register(
        email: email,
        password: password,
        username: username,
        phone: phone,
        role: 'customer',
      );
      final uid = FirebaseDbService.currentUser!.uid;
      _profile = await FirebaseDbService.getUserProfile(uid);
      _isLoading = false;
      notifyListeners();
      return _profile != null;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e.code);
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

  /// Logout from Firebase Auth
  Future<void> logout() async {
    await FirebaseDbService.signOut();
    _profile = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Email tidak terdaftar.';
      case 'wrong-password':
        return 'Password salah.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'email-already-in-use':
        return 'Email sudah digunakan.';
      case 'weak-password':
        return 'Password terlalu lemah (min. 6 karakter).';
      case 'invalid-credential':
        return 'Email atau password salah.';
      default:
        return 'Terjadi kesalahan: $code';
    }
  }
}
