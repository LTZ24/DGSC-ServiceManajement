import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic> _data = {};
  bool _isLoading = true;
  String? _error;
  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  Future<void> _handleBackPressed() async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.tr('Keluar dari akun?', 'Log out from this account?')),
            content: Text(
              context.tr(
                'Jika kembali dari dashboard, Anda akan logout dan masuk ke halaman beranda.',
                'If you go back from the dashboard, you will be logged out and returned to the home page.',
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

    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await BackendService.getAdminDashboardData();
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.lightBorder;
    final subtitleColor =
        isDark ? AppTheme.darkMutedText : const Color(0xFF667085);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.24)
        : const Color(0xFF0F172A).withValues(alpha: 0.08);
    final recentServices =
        ((_data['recentServices'] as List?)?.cast<Map<String, dynamic>>() ??
            []);
    final lowStockParts =
        ((_data['lowStockParts'] as List?)?.cast<Map<String, dynamic>>() ?? []);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Dashboard Admin', 'Admin Dashboard')),
          actions: const [NotificationBell()],
        ),
        drawer: const AppDrawer(isAdmin: true),
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
                        blurRadius: 28,
                        offset: const Offset(0, 14),
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
                              Icons.dashboard_customize_rounded,
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
                            child: Text(
                              _isLoading
                                  ? context.tr('Memuat...', 'Loading...')
                                  : context.tr('Data terbaru', 'Latest data'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        context.tr(
                          'Ringkasan Operasional\nHari Ini',
                          'Today\'s\nOperational Summary',
                        ),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr(
                          'Pantau servis aktif, booking menunggu, pelanggan, dan pendapatan dalam satu tampilan sederhana.',
                          'Monitor active services, pending bookings, customers, and revenue in one simple view.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroMiniStat(
                              label: context.tr('Pelanggan', 'Customers'),
                              value: _isLoading
                                  ? '...'
                                  : '${_data['totalCustomers'] ?? 0}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _HeroMiniStat(
                              label: context.tr('Pendapatan', 'Revenue'),
                              value: _isLoading
                                  ? '...'
                                  : currencyFormat
                                      .format(_data['paidRevenue'] ?? 0),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppTheme.dangerColor.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.dangerColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Gagal memuat data dashboard', 'Failed to load dashboard data'),
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _error!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _loadDashboard,
                          child: Text(context.tr('Coba Lagi', 'Try Again')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                _DashboardSectionHeader(
                  title: context.tr('Statistik Utama', 'Main Statistics'),
                  subtitle: context.tr('Ringkasan performa servis toko', 'Summary of store service performance'),
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
                      title: context.tr('Total Servis', 'Total Services'),
                      value:
                          _isLoading ? '...' : '${_data['totalServices'] ?? 0}',
                      icon: Icons.build,
                      color: AppTheme.primaryColor,
                      onTap: () =>
                          Navigator.pushNamed(context, '/admin/services'),
                    ),
                    StatCard(
                      title: context.tr('Selesai', 'Completed'),
                      value: _isLoading
                          ? '...'
                          : '${_data['completedServices'] ?? 0}',
                      icon: Icons.check_circle,
                      color: AppTheme.successColor,
                    ),
                    StatCard(
                      title: context.tr('Diproses', 'In Progress'),
                      value: _isLoading
                          ? '...'
                          : '${_data['inProgressServices'] ?? 0}',
                      icon: Icons.hourglass_bottom,
                      color: AppTheme.infoColor,
                    ),
                    StatCard(
                      title: context.tr('Menunggu', 'Pending'),
                      value: _isLoading
                          ? '...'
                          : '${_data['pendingServices'] ?? 0}',
                      icon: Icons.pending,
                      color: AppTheme.warningColor,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if ((_data['pendingBookings'] as int? ?? 0) > 0)
                  _HighlightBanner(
                    color: AppTheme.warningColor,
                    icon: Icons.calendar_today,
                    title: '${_data['pendingBookings']} ${context.tr('Booking Menunggu', 'Pending Bookings')}',
                    subtitle: context.tr('Booking baru perlu segera ditinjau admin.', 'New bookings need to be reviewed by admin soon.'),
                    onTap: () =>
                        Navigator.pushNamed(context, '/admin/bookings'),
                  ),
                if ((_data['pendingBookings'] as int? ?? 0) > 0)
                  const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _InfoPanel(
                        color: AppTheme.accentColor,
                        icon: Icons.people_alt_outlined,
                        title: context.tr('Pelanggan', 'Customers'),
                        value: _isLoading
                            ? '...'
                            : '${_data['totalCustomers'] ?? 0}',
                        subtitle: context.tr('Total customer terdaftar', 'Total registered customers'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoPanel(
                        color: AppTheme.successColor,
                        icon: Icons.account_balance_wallet_outlined,
                        title: context.tr('Pendapatan', 'Revenue'),
                        value: _isLoading
                            ? '...'
                            : currencyFormat.format(_data['paidRevenue'] ?? 0),
                        subtitle: context.tr('Pendapatan yang sudah lunas', 'Revenue already paid'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _DashboardSectionHeader(
                  title: context.tr('Servis Terbaru', 'Latest Services'),
                  subtitle: context.tr('Pantau aktivitas servis terakhir', 'Monitor the latest service activity'),
                ),
                const SizedBox(height: 12),
                if (recentServices.isEmpty)
                  _EmptyDashboardCard(
                    icon: Icons.build_circle_outlined,
                    label: context.tr('Belum ada servis terbaru', 'No recent services yet'),
                  )
                else
                  ...recentServices.map(
                    (service) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.build,
                              color: AppTheme.primaryColor),
                        ),
                        title: Text(
                          service['service_code'] ?? 'Service',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${service['customer_name'] ?? ''} • ${service['problem'] ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                              height: 1.4,
                            ),
                          ),
                        ),
                        trailing: StatusBadge(status: service['status'] ?? ''),
                        onTap: () =>
                            Navigator.pushNamed(context, '/admin/services'),
                      ),
                    ),
                  ),
                if (lowStockParts.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const _DashboardSectionHeader(
                    title: 'Stok Habis',
                    subtitle: 'Spare part yang perlu segera diisi ulang',
                  ),
                  const SizedBox(height: 12),
                  ...lowStockParts.map(
                    (part) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppTheme.dangerColor.withValues(alpha: 0.14),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.dangerColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.dangerColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  part['part_name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr(
                                    'Spare part yang perlu segera diisi ulang',
                                    'Spare parts that need to be restocked soon',
                                  ),
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _DashboardSectionHeader({
    required this.title,
    required this.subtitle,
  });

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

class _HeroMiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HighlightBanner({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.14 : 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkMutedText
                            : const Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _InfoPanel({
    required this.color,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.14 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkMutedText
                  : const Color(0xFF667085),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDashboardCard extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EmptyDashboardCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(icon,
              size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
