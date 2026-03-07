import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/firebase_db_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/stat_card.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});
  @override
  State<CustomerDashboardScreen> createState() => _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  Map<String, int> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    final uid = FirebaseDbService.currentUser?.uid ?? '';
    _stats = await FirebaseDbService.getCustomerDashboardStats(uid);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [NotificationBell()],
      ),
      drawer: const AppDrawer(isAdmin: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat Datang, ${FirebaseDbService.currentUser?.displayName ?? FirebaseDbService.currentUser?.email ?? ""}!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        StatCard(
                          title: 'Total Booking',
                          value: '${_stats['totalBookings'] ?? 0}',
                          icon: Icons.calendar_today,
                          color: AppTheme.primaryColor,
                          onTap: () => Navigator.pushNamed(context, '/customer/status'),
                        ),
                        StatCard(
                          title: 'Dalam Proses',
                          value: '${_stats['pendingCount'] ?? 0}',
                          icon: Icons.hourglass_empty,
                          color: AppTheme.warningColor,
                        ),
                        StatCard(
                          title: 'Selesai',
                          value: '${_stats['completedCount'] ?? 0}',
                          icon: Icons.check_circle,
                          color: AppTheme.successColor,
                        ),
                        StatCard(
                          title: 'Diagnosis',
                          value: 'CF',
                          icon: Icons.medical_services,
                          color: AppTheme.infoColor,
                          onTap: () => Navigator.pushNamed(context, '/customer/diagnosis'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Aksi Cepat',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/customer/booking'),
                        icon: const Icon(Icons.add),
                        label: const Text('Booking Baru'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/customer/status'),
                        icon: const Icon(Icons.list),
                        label: const Text('Lihat Status'),
                      )),
                    ]),
                  ],
                ),
              ),
            ),
    );
  }
}