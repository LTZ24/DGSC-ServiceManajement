import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/customer/customer_dashboard.dart';
import 'services/backend_service.dart';
import 'providers/auth_provider.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  StreamSubscription<AuthState>? _authSubscription;

  bool _isLoading = true;
  String? _role;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _checkInitialAuth();
    });
    _checkInitialAuth();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialAuth() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (!mounted) return;
      setState(() {
        _role = null;
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
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _role = role;
    });

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
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const HomeScreen();
    }

    if (_role == 'admin') {
      return const AdminDashboardScreen();
    }

    return const CustomerDashboardScreen();
  }
}
