import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_service.dart';
import '../../services/push_notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

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
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final roleArg = args?['role'] as String?;
    final requiredRole = roleArg == 'admin'
        ? 'admin'
        : roleArg == 'customer'
            ? 'customer'
            : null;
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _identifierController.text.trim(),
      _passwordController.text,
      requiredRole: requiredRole,
    );

    if (!success || !mounted) return;

    TextInput.finishAutofillContext(shouldSave: true);

    unawaited(
      PushNotificationService.requestFirstLoginPermissions(
        context,
        userId: authProvider.currentUser?.uid,
        role: authProvider.isAdmin ? 'admin' : 'customer',
      ),
    );

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/auth-wrapper',
      (route) => false,
    );
  }

  Future<void> _handleGoogleLogin() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();

    if (!success || !mounted) return;

    unawaited(
      PushNotificationService.requestFirstLoginPermissions(
        context,
        userId: authProvider.currentUser?.uid,
        role: 'customer',
      ),
    );
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/customer/dashboard',
      (route) => false,
    );
  }

  Future<void> _handleForgotPassword() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isAdmin = args?['role'] == 'admin';
    final emailController = TextEditingController(
      text: _identifierController.text.contains('@')
          ? _identifierController.text.trim()
          : '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Reset Password', 'Reset Password')),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: context.tr('Email akun', 'Account email'),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Batal', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Kirim', 'Send')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr(
                'Masukkan email yang valid.', 'Enter a valid email.'))),
      );
      return;
    }

    try {
      await BackendService.sendPasswordResetEmail(email);
      await BackendService.savePasswordResetRole(
          isAdmin ? 'admin' : 'customer');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Email reset password telah dikirim.',
              'Password reset email has been sent.')),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${context.tr('Gagal mengirim email reset', 'Failed to send reset email')}: $e'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isAdmin = args?['role'] == 'admin';
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
    final roleTitle = isAdmin ? 'Login Admin' : 'Login Customer';
    final roleSubtitle = isAdmin
        ? context.tr(
            'Masuk ke panel admin untuk mengelola servis, transaksi, dan inventaris.',
            'Sign in to the admin panel to manage services, transactions, and inventory.',
          )
        : context.tr(
            'Masuk untuk booking servis, cek status perangkat, dan lihat riwayat perbaikan.',
            'Sign in to book services, check device status, and view repair history.',
          );

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
                    child: AutofillGroup(
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
                                color: secondarySurfaceColor.withValues(
                                    alpha: 0.75),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: borderColor),
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.phone_android,
                                  size: 52,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            roleTitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              roleSubtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                height: 1.6,
                                color: subtitleColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
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
                                  controller: _identifierController,
                                  keyboardType: TextInputType.text,
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.email,
                                    AutofillHints.telephoneNumber,
                                  ],
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: context.tr(
                                        'Email / Username / Nomor HP',
                                        'Email / Username / Phone Number'),
                                    prefixIcon:
                                        const Icon(Icons.alternate_email),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return context.tr(
                                          'Masukkan email, username, atau nomor HP',
                                          'Enter email, username, or phone number');
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _handleLogin(),
                                  decoration: InputDecoration(
                                    labelText:
                                        context.tr('Password', 'Password'),
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
                                      return context.tr('Masukkan password',
                                          'Enter password');
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _handleForgotPassword,
                                    child: Text(context.tr(
                                        'Lupa password?', 'Forgot password?')),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Consumer<AuthProvider>(
                                  builder: (context, auth, _) {
                                    return SizedBox(
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: auth.isLoading
                                            ? null
                                            : _handleLogin,
                                        child: auth.isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                context.tr('Masuk Sekarang',
                                                    'Sign In'),
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                      ),
                                    );
                                  },
                                ),
                                if (!isAdmin) ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: borderColor,
                                          thickness: 1,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text(
                                          context.tr('atau', 'or'),
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: subtitleColor,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: borderColor,
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Consumer<AuthProvider>(
                                    builder: (context, auth, _) {
                                      return SizedBox(
                                        height: 52,
                                        child: OutlinedButton(
                                          onPressed: auth.isLoading
                                              ? null
                                              : _handleGoogleLogin,
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor: surfaceColor
                                                .withValues(alpha: 0.92),
                                            side:
                                                BorderSide(color: borderColor),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const _GoogleLogo(size: 20),
                                              const SizedBox(width: 12),
                                              Text(
                                                context.tr(
                                                    'Masuk dengan Google',
                                                    'Sign in with Google'),
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w700,
                                                  color: theme.textTheme
                                                      .bodyLarge?.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                                const SizedBox(height: 14),
                                if (!isAdmin)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        context.tr('Belum punya akun? ',
                                            'Don\'t have an account? '),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          color: subtitleColor,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                              context, '/register');
                                        },
                                        child: Text(context.tr(
                                            'Daftar Sekarang', 'Register Now')),
                                      ),
                                    ],
                                  ),
                                if (isAdmin)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      context.tr(
                                        'Akun admin baru dibuat dari menu Pengaturan Admin.',
                                        'New admin accounts are created from the Admin Settings menu.',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        Navigator.pushReplacementNamed(
                                            context, '/home'),
                                    icon: const Icon(Icons.home_outlined,
                                        size: 16),
                                    label: Text(
                                      context.tr(
                                        'Kembali ke Beranda',
                                        'Back to Home',
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: subtitleColor,
                                    ),
                                  ),
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
            ),
          );
        },
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  final double size;

  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 8,
      height: size + 8,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size.square(size),
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.18;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    void drawArc(Color color, double start, double sweep) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, sweep, false, paint);
    }

    drawArc(const Color(0xFF4285F4), -0.35, 1.65);
    drawArc(const Color(0xFFEA4335), 1.35, 1.1);
    drawArc(const Color(0xFFFBBC05), 2.5, 1.05);
    drawArc(const Color(0xFF34A853), 3.55, 1.35);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final midY = size.height * 0.53;
    canvas.drawLine(
      Offset(size.width * 0.53, midY),
      Offset(size.width * 0.88, midY),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
