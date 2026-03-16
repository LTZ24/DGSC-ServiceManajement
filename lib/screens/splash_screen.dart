import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_biometric_service.dart';
import '../services/backend_service.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Small delay just to let the splash render before navigating
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final isLoggedIn = await authProvider.checkAuth();

    if (!mounted) return;

    if (isLoggedIn) {
      if (authProvider.isAdmin) {
        final shouldProtect =
            await AdminBiometricService.canUseBiometricLogin();
        if (shouldProtect) {
          final authenticated = await AdminBiometricService.authenticate();
          if (!authenticated) {
            await BackendService.signOut();
            if (!mounted) return;
            Navigator.pushReplacementNamed(
              context,
              '/login',
              arguments: {'role': 'admin'},
            );
            return;
          }
        }
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
      } else {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/customer/dashboard');
      }
    } else {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.phone_android,
                size: 100,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'DigiTech Service',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Service Center',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
