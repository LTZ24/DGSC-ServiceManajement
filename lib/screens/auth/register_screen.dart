import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().clearError();
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Registrasi berhasil. Silakan login terlebih dahulu.', 'Registration successful. Please sign in first.')),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pushReplacementNamed(
        context,
        '/login',
        arguments: {'role': 'customer'},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final secondarySurfaceColor =
        isDark ? AppTheme.darkSurfaceAlt : AppTheme.lightSurfaceAlt;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.lightBorder;
    final subtitleColor =
        isDark ? AppTheme.darkMutedText : const Color(0xFF667085);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.24)
        : const Color(0xFF0F172A).withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1724) : const Color(0xFFFFFFFF),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [
                        Color(0xFF0B1320),
                        Color(0xFF101A2C),
                        Color(0xFF0F1724),
                      ]
                    : const [
                        Color(0xFFF5F7FB),
                        Color(0xFFF9FAFC),
                        Color(0xFFFFFFFF),
                      ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            width: 92,
                            height: 92,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  secondarySurfaceColor.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: borderColor),
                            ),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person_add_alt_1_rounded,
                                size: 52,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('Registrasi Customer', 'Customer Registration'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(
                            'Lengkapi data untuk membuat akun dan mulai menggunakan layanan DigiTech Service.',
                            'Complete the form to create an account and start using DigiTech Service.',
                          ),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            height: 1.6,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                          decoration: BoxDecoration(
                            color: surfaceColor.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  if (auth.error == null) {
                                    return const SizedBox.shrink();
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.dangerColor
                                          .withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppTheme.dangerColor
                                            .withValues(alpha: 0.24),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: AppTheme.dangerColor,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            auth.error!,
                                            style: GoogleFonts.poppins(
                                              color: AppTheme.dangerColor,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: context.tr('Username', 'Username'),
                                  prefixIcon: const Icon(Icons.person_outline),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? context.tr('Username wajib diisi', 'Username is required')
                                        : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: context.tr('Nama Lengkap', 'Full Name'),
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? context.tr('Nama wajib diisi', 'Name is required')
                                        : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: context.tr('Email', 'Email'),
                                  prefixIcon: const Icon(Icons.email_outlined),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return context.tr('Email wajib diisi', 'Email is required');
                                  }
                                  if (!value.contains('@')) {
                                    return context.tr('Format email tidak valid', 'Invalid email format');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: context.tr('Nomor HP', 'Phone Number'),
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? context.tr('No. HP wajib diisi', 'Phone number is required')
                                        : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: context.tr('Password', 'Password'),
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return context.tr('Password wajib diisi', 'Password is required');
                                  }
                                  if (value.length < 6) {
                                    return context.tr('Minimal 6 karakter', 'Minimum 6 characters');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirm,
                                decoration: InputDecoration(
                                  labelText: context.tr('Konfirmasi Password', 'Confirm Password'),
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirm = !_obscureConfirm;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value != _passwordController.text) {
                                    return context.tr('Password tidak cocok', 'Passwords do not match');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  return SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: auth.isLoading
                                          ? null
                                          : _handleRegister,
                                      child: auth.isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              context.tr('Daftar Sekarang', 'Register Now'),
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    context.tr('Sudah punya akun? ', 'Already have an account? '),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      color: subtitleColor,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(context.tr('Masuk', 'Sign In')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
