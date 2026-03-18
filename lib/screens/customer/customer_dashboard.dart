import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/stat_card.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  Map<String, int> _stats = {
    'totalBookings': 0,
    'pendingCount': 0,
    'completedCount': 0,
  };
  bool _isLoading = true;
  String _displayName = '';

  Future<void> _handleBackPressed() async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.tr('Keluar dari akun?', 'Log out from this account?')),
            content: Text(
              context.tr(
                'Jika kembali dari dashboard, Anda akan logout dan masuk ke halaman login.',
                'If you go back from the dashboard, you will be logged out and returned to the login page.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.tr('Batal', 'Cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.tr('Keluar', 'Logout')),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldLogout || !mounted) return;

    await context.read<AuthProvider>().logout();
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
      arguments: {'role': 'customer'},
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    final uid = BackendService.currentUser?.uid ?? '';
    final results = await Future.wait([
      BackendService.getCustomerDashboardStats(uid),
      BackendService.getUserProfile(uid),
    ]);
    _stats = results[0] as Map<String, int>;
    final profile = results[1];
    _displayName = (profile?['username'] ??
            BackendService.currentUser?.displayName ??
            BackendService.currentUser?.email ??
            '')
        .toString();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final greetingName =
        _displayName.isEmpty ? context.tr('Pelanggan', 'Customer') : _displayName;
    final welcomePrefix = context.tr('Selamat Datang', 'Welcome');
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.lightBorder;
    final subtitleColor =
        isDark ? AppTheme.darkMutedText : const Color(0xFF667085);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.24)
        : const Color(0xFF0F172A).withValues(alpha: 0.08);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Dashboard', 'Dashboard')),
          actions: const [NotificationBell()],
        ),
        drawer: const AppDrawer(isAdmin: false),
        body: Container(
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
          child: RefreshIndicator(
            onRefresh: _loadDashboard,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoading) const LinearProgressIndicator(),
                if (_isLoading) const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.waving_hand_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'DGSC Mobile',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '$welcomePrefix,\n$greetingName!',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr(
                          'Pantau booking, progres servis, dan lakukan booking baru dengan cepat.',
                          'Track bookings, service progress, and create a new booking quickly.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionHeader(
                  title: context.tr('Ringkasan', 'Summary'),
                  subtitle: context.tr('Informasi utama akun Anda', 'Your main account information'),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.18,
                  children: [
                    StatCard(
                      title: context.tr('Total Booking', 'Total Bookings'),
                      value: _isLoading
                          ? '...'
                          : '${_stats['totalBookings'] ?? 0}',
                      icon: Icons.calendar_today,
                      color: AppTheme.primaryColor,
                      onTap: () =>
                          Navigator.pushNamed(context, '/customer/status'),
                    ),
                    StatCard(
                      title: context.tr('Dalam Proses', 'In Progress'),
                      value:
                          _isLoading ? '...' : '${_stats['pendingCount'] ?? 0}',
                      icon: Icons.hourglass_empty,
                      color: AppTheme.warningColor,
                    ),
                    StatCard(
                      title: context.tr('Selesai', 'Completed'),
                      value: _isLoading
                          ? '...'
                          : '${_stats['completedCount'] ?? 0}',
                      icon: Icons.check_circle,
                      color: AppTheme.successColor,
                    ),
                    StatCard(
                      title: context.tr('Diagnosis', 'Diagnosis'),
                      value: 'CF',
                      icon: Icons.medical_services,
                      color: AppTheme.infoColor,
                      onTap: () =>
                          Navigator.pushNamed(context, '/customer/diagnosis'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: context.tr('Aksi Cepat', 'Quick Actions'),
                  subtitle: context.tr('Menu yang paling sering digunakan', 'Most frequently used menu'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        title: context.tr('Booking Baru', 'New Booking'),
                        subtitle: context.tr('Buat permintaan servis baru', 'Create a new service request'),
                        icon: Icons.add_circle_outline_rounded,
                        color: AppTheme.primaryColor,
                        onTap: () =>
                            Navigator.pushNamed(context, '/customer/booking'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        title: context.tr('Lihat Status', 'View Status'),
                        subtitle: context.tr('Pantau progres servis Anda', 'Track your service progress'),
                        icon: Icons.track_changes_outlined,
                        color: AppTheme.infoColor,
                        onTap: () =>
                            Navigator.pushNamed(context, '/customer/status'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: surfaceColor.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.tips_and_updates_outlined,
                          color: AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Tips Cepat', 'Quick Tips'),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('Lakukan diagnosis terlebih dahulu untuk membantu admin memahami masalah perangkat Anda.', 'Run a diagnosis first to help the admin understand your device problem.'),
                              style: TextStyle(
                                color: subtitleColor,
                                height: 1.4,
                                fontSize: 12,
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
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final subtitleColor = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkMutedText
        : const Color(0xFF667085);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            color: subtitleColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: surfaceColor.withValues(alpha: 0.96),
            border: Border.all(color: color.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.14 : 0.10),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color:
                      isDark ? AppTheme.darkMutedText : const Color(0xFF667085),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
