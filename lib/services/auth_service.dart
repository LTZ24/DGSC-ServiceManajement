import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  /// Login with username/email/phone + password
  static Future<AuthResult> login(String identifier, String password) async {
    // The PHP app uses form-based login, so we POST to login.php
    // For API-based auth, we'll use a custom approach
    final response = await ApiService.post(
      '${ApiConfig.baseUrl}/../login.php',
      body: {
        'login_identifier': identifier,
        'password': password,
        'api_mode': true, // Signal we want JSON response
      },
    );

    if (response.success && response.data['success'] == true) {
      final user = User.fromJson(response.data['user']);
      await _saveUser(user);
      return AuthResult(success: true, user: user);
    }

    return AuthResult(
      success: false,
      message: response.message,
    );
  }

  /// Register new customer account
  static Future<AuthResult> register({
    required String username,
    required String email,
    required String name,
    required String phone,
    required String password,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.baseUrl}/../register.php',
      body: {
        'username': username,
        'email': email,
        'name': name,
        'phone': phone,
        'password': password,
        'confirm_password': password,
        'api_mode': true,
      },
    );

    if (response.success && response.data['success'] == true) {
      final user = User.fromJson(response.data['user']);
      await _saveUser(user);
      return AuthResult(success: true, user: user);
    }

    return AuthResult(
      success: false,
      message: response.message,
    );
  }

  /// Check if user is currently logged in
  static Future<AuthResult> checkAuth() async {
    final response = await ApiService.get(
      ApiConfig.auth,
      queryParams: {'action': 'check'},
    );

    if (response.success && response.data['logged_in'] == true) {
      final user = User.fromJson(response.data['user']);
      await _saveUser(user);
      return AuthResult(success: true, user: user);
    }

    // Try to load cached user
    final cachedUser = await getCachedUser();
    if (cachedUser != null) {
      return AuthResult(success: true, user: cachedUser);
    }

    return AuthResult(success: false, message: 'Not logged in');
  }

  /// Logout
  static Future<void> logout() async {
    await ApiService.get('${ApiConfig.baseUrl}/../logout.php');
    await ApiService.clearSession();
  }

  /// Save user data locally
  static Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user.toJson()));
  }

  /// Get cached user from local storage
  static Future<User?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData != null) {
      try {
        return User.fromJson(jsonDecode(userData));
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class AuthResult {
  final bool success;
  final User? user;
  final String? message;

  AuthResult({
    required this.success,
    this.user,
    this.message,
  });
}
