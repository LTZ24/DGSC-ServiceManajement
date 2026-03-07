import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

/// Pre-login landing page — mirrors the web index.php homepage with 3 menu cards.
/// Auto-redirects to dashboard if user is already logged in.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _checkedAuth = false;

  @override
  void initState() {
    super.initState();
    _checkAndRedirect();
  }

  Future<void> _checkAndRedirect() async {
    final authProvider = context.read<AuthProvider>();
    final isLoggedIn = await authProvider.checkAuth();

    if (!mounted) return;

    if (isLoggedIn) {
      if (authProvider.isAdmin) {
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/customer/dashboard');
      }
    } else {
      setState(() => _checkedAuth = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking auth
    if (!_checkedAuth) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isSmall = MediaQuery.of(context).size.width < 400;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Top bar: dark mode + info ──────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dark mode toggle
                  Row(
                    children: [
                      Icon(isDark ? Icons.dark_mode : Icons.light_mode,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: isDark,
                          onChanged: (_) => themeProvider.toggleTheme(),
                          activeThumbColor: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  // [!] Info Button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline,
                          color: AppTheme.primaryColor, size: 20),
                    ),
                    onPressed: () => _showAppInfo(context),
                    tooltip: 'Info Aplikasi',
                  ),
                ],
              ),

              // ── Logo section ──────────────────────────────────
              const SizedBox(height: 8),
              Image.asset(
                'assets/images/logo.png',
                width: 90,
                height: 90,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.phone_android,
                      size: 50, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.poppins(
                    fontSize: isSmall ? 22 : 26,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                  children: const [
                    TextSpan(text: 'DigiTech '),
                    TextSpan(
                      text: 'Service',
                      style: TextStyle(color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Solusi lengkap servis perangkat & manajemen transaksi konter',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : const Color(0xFF7C7C8A),
                ),
              ),

              const SizedBox(height: 36),

              // ── 3 menu cards ──────────────────────────────────
              _MenuCard(
                icon: Icons.medical_services_rounded,
                iconBgColor: AppTheme.primaryColor,
                iconFgColor: Colors.white,
                title: 'Sistem Diagnosa',
                subtitle:
                    'Diagnosa kerusakan perangkat menggunakan teknologi Certainty Factor',
                badge: '⚡ AI-Powered',
                onTap: () => Navigator.pushNamed(context, '/diagnosis'),
              ),
              const SizedBox(height: 16),
              _MenuCard(
                icon: Icons.person_rounded,
                iconBgColor: const Color(0x14FF6B35),
                iconFgColor: AppTheme.primaryColor,
                borderColor: const Color(0x26FF6B35),
                title: 'Login Customer',
                subtitle:
                    'Akses booking servis, cek status perangkat, dan riwayat perbaikan',
                badge: '🛡 Customer Area',
                onTap: () =>
                    Navigator.pushNamed(context, '/login', arguments: {'role': 'customer'}),
              ),
              const SizedBox(height: 16),
              _MenuCard(
                icon: Icons.admin_panel_settings_rounded,
                iconBgColor: const Color(0x14FF6B35),
                iconFgColor: AppTheme.primaryColor,
                borderColor: const Color(0x26FF6B35),
                title: 'Login Admin',
                subtitle:
                    'Kelola servis, transaksi konter PPOB, keuangan, dan inventaris',
                badge: '🔒 Admin Panel',
                onTap: () =>
                    Navigator.pushNamed(context, '/login', arguments: {'role': 'admin'}),
              ),

              const SizedBox(height: 32),
              Text(
                '© ${DateTime.now().year} DigiTech Service Center',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.phone_android, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Info Aplikasi'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.apps, 'Nama', 'DigiTech Service Center'),
            _infoRow(Icons.info_outline, 'Versi', '1.0.0'),
            _infoRow(Icons.code, 'Developer', 'LTZ24'),
            _infoRow(Icons.link, 'GitHub', 'github.com/LTZ24'),
            _infoRow(Icons.storage, 'Server', 'Firebase Firestore (Cloud)'),
            _infoRow(Icons.cloud, 'Platform', 'Google Firebase'),
            _infoRow(Icons.phone_iphone, 'Build', 'Flutter 3.x'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _MenuCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconFgColor;
  final Color? borderColor;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconFgColor,
    this.borderColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(
              top: const BorderSide(color: AppTheme.primaryColor, width: 3),
              left: BorderSide(
                  color: borderColor ?? const Color(0xFFE8EAED), width: 1.5),
              right: BorderSide(
                  color: borderColor ?? const Color(0xFFE8EAED), width: 1.5),
              bottom: BorderSide(
                  color: borderColor ?? const Color(0xFFE8EAED), width: 1.5),
            ),
          ),
          padding: const EdgeInsets.all(22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon box
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: borderColor != null
                      ? Border.all(color: borderColor!, width: 1.5)
                      : null,
                ),
                child: Icon(icon, size: 28, color: iconFgColor),
              ),
              const SizedBox(width: 16),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: const Color(0xFF7C7C8A),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x14FF6B35),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: Color(0xFFA0A0AE)),
            ],
          ),
        ),
      ),
    );
  }
}
