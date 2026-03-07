import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class AppDrawer extends StatelessWidget {
  final bool isAdmin;
  const AppDrawer({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Drawer(
      child: Column(
        children: [
          // Header
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primaryColor),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                ((profile?['username'] as String?) ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            accountName: Text(
              (profile?['username'] as String?) ?? 'User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text((profile?['email'] as String?) ?? ''),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: isAdmin ? _adminMenuItems(context) : _customerMenuItems(context),
            ),
          ),

          // Logout
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.dangerColor),
            title: const Text('Keluar',
                style: TextStyle(color: AppTheme.dangerColor)),
            onTap: () async {
              Navigator.pop(context);
              await auth.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<Widget> _adminMenuItems(BuildContext context) {
    return [
      _buildMenuItem(context, Icons.dashboard, 'Dashboard', '/admin/dashboard'),
      _buildMenuItem(context, Icons.calendar_today, 'Booking', '/admin/bookings'),
      _buildMenuItem(context, Icons.build, 'Servis', '/admin/services'),
      _buildMenuItem(context, Icons.people, 'Pelanggan', '/admin/customers'),
      _buildMenuItem(context, Icons.account_balance_wallet, 'Keuangan', '/admin/finance'),
      _buildMenuItem(context, Icons.inventory, 'Spare Part', '/admin/spare-parts'),
      _buildMenuItem(context, Icons.point_of_sale, 'Counter', '/admin/counter'),
      _buildMenuItem(context, Icons.store, 'Pengaturan Toko', '/admin/store-settings'),
      _buildMenuItem(context, Icons.settings, 'Pengaturan', '/admin/settings'),
    ];
  }

  List<Widget> _customerMenuItems(BuildContext context) {
    return [
      _buildMenuItem(context, Icons.dashboard, 'Dashboard', '/customer/dashboard'),
      _buildMenuItem(context, Icons.add_circle, 'Booking Servis', '/customer/booking'),
      _buildMenuItem(context, Icons.medical_services, 'Diagnosis', '/customer/diagnosis'),
      _buildMenuItem(context, Icons.track_changes, 'Status Servis', '/customer/status'),
      _buildMenuItem(context, Icons.history, 'Riwayat', '/customer/history'),
      _buildMenuItem(context, Icons.person, 'Profil', '/customer/profile'),
      _buildMenuItem(context, Icons.settings, 'Pengaturan', '/customer/settings'),
    ];
  }

  Widget _buildMenuItem(
      BuildContext context, IconData icon, String title, String route) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isActive = currentRoute == route;

    return ListTile(
      leading: Icon(icon,
          color: isActive ? AppTheme.primaryColor : Colors.grey.shade600),
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? AppTheme.primaryColor : null,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isActive,
      selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (!isActive) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
    );
  }
}
