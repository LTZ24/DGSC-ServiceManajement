import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/firebase_db_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await FirebaseDbService.getAdminDashboardData();
      setState(() { _data = data; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: const [NotificationBell()],
      ),
      drawer: const AppDrawer(isAdmin: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.dangerColor, size: 48),
                      const SizedBox(height: 12),
                      Text('Gagal memuat data', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _loadDashboard, child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // KPI Cards
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.3,
                          children: [
                            StatCard(
                              title: 'Total Servis',
                              value: '${_data['totalServices'] ?? 0}',
                              icon: Icons.build,
                              color: AppTheme.primaryColor,
                              onTap: () => Navigator.pushNamed(context, '/admin/services'),
                            ),
                            StatCard(
                              title: 'Selesai',
                              value: '${_data['completedServices'] ?? 0}',
                              icon: Icons.check_circle,
                              color: AppTheme.successColor,
                            ),
                            StatCard(
                              title: 'Sedang Dikerjakan',
                              value: '${_data['inProgressServices'] ?? 0}',
                              icon: Icons.hourglass_bottom,
                              color: AppTheme.infoColor,
                            ),
                            StatCard(
                              title: 'Menunggu',
                              value: '${_data['pendingServices'] ?? 0}',
                              icon: Icons.pending,
                              color: AppTheme.warningColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Revenue & Customers
                        Row(
                          children: [
                            Expanded(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.people, color: AppTheme.accentColor),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${_data['totalCustomers'] ?? 0}',
                                        style: Theme.of(context).textTheme.titleLarge
                                            ?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const Text('Pelanggan',
                                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.account_balance_wallet,
                                          color: AppTheme.successColor),
                                      const SizedBox(height: 8),
                                      Text(
                                        currencyFormat.format(_data['paidRevenue'] ?? 0),
                                        style: Theme.of(context).textTheme.titleSmall
                                            ?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const Text('Pendapatan',
                                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Pending bookings alert
                        if ((_data['pendingBookings'] as int? ?? 0) > 0)
                          Card(
                            color: AppTheme.warningColor.withValues(alpha: 0.1),
                            child: ListTile(
                              leading: const Icon(Icons.calendar_today, color: Colors.orange),
                              title: Text(
                                '${_data['pendingBookings']} Booking Menunggu',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text('Booking baru perlu ditinjau',
                                  style: TextStyle(fontSize: 12)),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => Navigator.pushNamed(context, '/admin/bookings'),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Recent Services
                        Text(
                          'Servis Terbaru',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if ((_data['recentServices'] as List?)?.isEmpty ?? true)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text('Belum ada servis',
                                    style: TextStyle(color: Colors.grey)),
                              ),
                            ),
                          )
                        else
                          ...((_data['recentServices'] as List).cast<Map<String, dynamic>>())
                              .map((service) => Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                        child: const Icon(Icons.build,
                                            color: AppTheme.primaryColor, size: 20),
                                      ),
                                      title: Text(
                                        service['service_code'] ?? 'Service',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        '${service['customer_name'] ?? ''} - ${service['problem'] ?? ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: StatusBadge(status: service['status'] ?? ''),
                                      onTap: () =>
                                          Navigator.pushNamed(context, '/admin/services'),
                                    ),
                                  )),

                        // Low Stock Parts Alert
                        if ((_data['lowStockParts'] as List?)?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Stok Habis',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.dangerColor,
                                ),
                          ),
                          const SizedBox(height: 8),
                          ...((_data['lowStockParts'] as List).cast<Map<String, dynamic>>())
                              .map((part) => Card(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    child: ListTile(
                                      leading: const Icon(Icons.warning,
                                          color: AppTheme.dangerColor),
                                      title: Text(part['part_name'] ?? '',
                                          style: const TextStyle(fontSize: 14)),
                                      trailing: Text(
                                        'Stok: ${part['stock_quantity']}',
                                        style: const TextStyle(
                                            color: AppTheme.dangerColor,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  )),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }
}
