import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../l10n/app_text.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
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

  void _toggleLocale(LocaleProvider localeProvider) {
    localeProvider.setLocale(localeProvider.isEnglish ? 'id' : 'en');
  }

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
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/admin/dashboard',
          (route) => false,
        );
      } else {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/customer/dashboard',
          (route) => false,
        );
      }
    } else {
      setState(() => _checkedAuth = true);
    }
  }

  Future<void> _refreshHome() async {
    await _checkAndRedirect();
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
    final isCompactHeader = MediaQuery.of(context).size.width < 380;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final isDark = themeProvider.isDark;
    final surfaceColor = isDark ? const Color(0xFF162033) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE7EAF1);
    final secondarySurfaceColor =
        isDark ? const Color(0xFF1C2940) : const Color(0xFFF8FAFC);
    final subtitleColor =
        isDark ? const Color(0xFFB6C2D2) : const Color(0xFF667085);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.24)
        : const Color(0xFF0F172A).withValues(alpha: 0.08);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF0B1320),
                    Color(0xFF101A2C),
                    Color(0xFF0F1724)
                  ]
                : const [
                    Color(0xFFF5F7FB),
                    Color(0xFFF9FAFC),
                    Color(0xFFFFFFFF)
                  ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator.adaptive(
            onRefresh: _refreshHome,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                isCompactHeader ? 12 : 16,
                20,
                isCompactHeader ? 16 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    isCompactHeader ? 18 : 20,
                    isCompactHeader ? 18 : 24,
                    isCompactHeader ? 18 : 20,
                    isCompactHeader ? 18 : 24,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceColor.withValues(alpha: isDark ? 0.94 : 0.98),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompactHeader ? 10 : 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                context.tr(
                                  'Service Management App',
                                  'Service Management App',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: isCompactHeader ? 10.5 : 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _headerLanguageButton(
                            isCompact: isCompactHeader,
                            isEnglish: localeProvider.isEnglish,
                            onTap: () => _toggleLocale(localeProvider),
                          ),
                          const SizedBox(width: 8),
                          _headerActionButton(
                            icon: isDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            onTap: themeProvider.toggleTheme,
                            isCompact: isCompactHeader,
                            isActive: isDark,
                          ),
                          const SizedBox(width: 8),
                          _headerActionButton(
                            icon: Icons.info_outline_rounded,
                            onTap: () => _showAppInfo(context),
                            isCompact: isCompactHeader,
                          ),
                        ],
                      ),
                      SizedBox(height: isCompactHeader ? 16 : 20),
                      Container(
                        width: isCompactHeader ? 88 : 104,
                        height: isCompactHeader ? 88 : 104,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: secondarySurfaceColor,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.10),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.phone_android,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isCompactHeader ? 12 : 16),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.poppins(
                            fontSize: isSmall ? 24 : 28,
                            fontWeight: FontWeight.w800,
                            color: textTheme.titleLarge?.color,
                            height: 1.2,
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
                      SizedBox(height: isCompactHeader ? 8 : 10),
                      Text(
                        context.tr(
                          'Solusi lengkap servis perangkat dan manajemen transaksi konter dalam satu aplikasi yang rapi, cepat, dan mudah digunakan.',
                          'A complete solution for device service and counter transaction management in one clean, fast, and easy-to-use app.',
                        ),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: isCompactHeader ? 12.5 : 13,
                          height: isCompactHeader ? 1.55 : 1.7,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isCompactHeader ? 20 : 26),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      context.tr('Menu Utama', 'Main Menu'),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textTheme.titleMedium?.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _MenuCard(
                  icon: Icons.psychology_alt_rounded,
                  iconBgColor: AppTheme.primaryColor,
                  iconFgColor: Colors.white,
                  title: context.tr('Sistem Diagnosa', 'Diagnosis System'),
                  subtitle: context.tr(
                      'Diagnosa kerusakan perangkat dengan alur yang sederhana dan hasil yang cepat dipahami.',
                      'Diagnose device issues with a simple flow and easy-to-understand results.'),
                  badge: context.tr('AI-Powered', 'AI-Powered'),
                  accentColor: AppTheme.primaryColor,
                  onTap: () => Navigator.pushNamed(context, '/diagnosis'),
                ),
                const SizedBox(height: 16),
                _MenuCard(
                  icon: Icons.person_outline_rounded,
                  iconBgColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                  iconFgColor: AppTheme.primaryColor,
                  title: context.tr('Login Customer', 'Customer Login'),
                  subtitle: context.tr(
                      'Akses booking servis, cek status perangkat, dan lihat riwayat perbaikan secara praktis.',
                      'Access service booking, device status, and repair history easily.'),
                  badge: context.tr('Area Customer', 'Customer Area'),
                  accentColor: const Color(0xFF22C55E),
                  onTap: () => Navigator.pushNamed(context, '/login',
                      arguments: {'role': 'customer'}),
                ),
                const SizedBox(height: 16),
                _MenuCard(
                  icon: Icons.admin_panel_settings_outlined,
                  iconBgColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                  iconFgColor: AppTheme.primaryColor,
                  title: context.tr('Login Admin', 'Admin Login'),
                  subtitle: context.tr(
                      'Kelola servis, transaksi konter PPOB, keuangan, dan inventaris dengan panel yang terpusat.',
                      'Manage services, counter transactions, finance, and inventory from one central panel.'),
                  badge: context.tr('Panel Admin', 'Admin Panel'),
                  accentColor: const Color(0xFF6366F1),
                  onTap: () => Navigator.pushNamed(context, '/login',
                      arguments: {'role': 'admin'}),
                ),
                const SizedBox(height: 30),
                Text(
                  '© ${DateTime.now().year} DigiTech Service Center',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: subtitleColor,
                  ),
                ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAppInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.phone_android, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(context.tr('Info Aplikasi', 'App Info')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.apps, context.tr('Nama', 'Name'),
                'DigiTech Service Center'),
            _infoRow(
              Icons.info_outline, context.tr('Versi', 'Version'), '1.0.2'),
            _infoRow(Icons.code, context.tr('Developer', 'Developer'),
                'Muhamad Latip M.'),
            _infoRow(Icons.link, 'GitHub', 'github.com/LTZ24'),
            _infoRow(Icons.storage, context.tr('Server', 'Server'),
              'Supabase PostgreSQL'),
            _infoRow(Icons.phone_iphone, 'Build', 'Flutter 3.x'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Tutup', 'Close')),
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
          Text('$label: ',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isCompact,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: isCompact ? 38 : 42,
        height: isCompact ? 38 : 42,
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.18)
              : AppTheme.primaryColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, animation) => RotationTransition(
            turns: Tween<double>(begin: 0.88, end: 1).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(
            icon,
            key: ValueKey(icon),
            color: AppTheme.primaryColor,
            size: isCompact ? 20 : 22,
          ),
        ),
      ),
    );
  }

  Widget _headerLanguageButton({
    required VoidCallback onTap,
    required bool isCompact,
    required bool isEnglish,
  }) {
    final icon = isEnglish ? Icons.language_rounded : Icons.translate_rounded;
    final label = isEnglish ? 'EN' : 'ID';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        width: isCompact ? 62 : 70,
        height: isCompact ? 38 : 42,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: Row(
            key: ValueKey(label),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isCompact ? 17 : 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 11.5 : 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _MenuCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconFgColor;
  final String title;
  final String subtitle;
  final String badge;
  final Color accentColor;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconFgColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCompact = MediaQuery.of(context).size.width < 400;
    final surfaceColor = isDark ? const Color(0xFF162033) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE7EAF1);
    final subtitleColor =
        isDark ? const Color(0xFFB6C2D2) : const Color(0xFF667085);

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: const [],
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 16 : 20,
                  isCompact ? 20 : 24,
                  isCompact ? 16 : 20,
                  isCompact ? 16 : 20,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: isCompact ? 52 : 60,
                      height: isCompact ? 52 : 60,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius:
                            BorderRadius.circular(isCompact ? 16 : 18),
                      ),
                      child: Icon(
                        icon,
                        size: isCompact ? 24 : 28,
                        color: iconFgColor,
                      ),
                    ),
                    SizedBox(width: isCompact ? 14 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: GoogleFonts.poppins(
                                    fontSize: isCompact ? 16 : 18,
                                    fontWeight: FontWeight.w700,
                                    color: theme.textTheme.titleMedium?.color,
                                  ),
                                ),
                              ),
                              SizedBox(width: isCompact ? 8 : 10),
                              Container(
                                width: isCompact ? 30 : 34,
                                height: isCompact ? 30 : 34,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(
                                      isCompact ? 10 : 12),
                                ),
                                child: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: isCompact ? 14 : 16,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isCompact ? 6 : 8),
                          Text(
                            subtitle,
                            style: GoogleFonts.poppins(
                              fontSize: isCompact ? 12 : 12.8,
                              height: isCompact ? 1.45 : 1.6,
                              color: subtitleColor,
                            ),
                          ),
                          SizedBox(height: isCompact ? 10 : 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge,
                              style: GoogleFonts.poppins(
                                fontSize: isCompact ? 10.5 : 11,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
