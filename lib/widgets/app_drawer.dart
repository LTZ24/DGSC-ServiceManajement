import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../providers/auth_provider.dart';

class AppDrawer extends StatelessWidget {
  final bool isAdmin;
  final bool isGuest;

  const AppDrawer({
    super.key,
    required this.isAdmin,
    this.isGuest = false,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayName =
        isGuest ? 'Guest' : (profile?['username'] as String?) ?? 'User';
    final displayEmail = isGuest
        ? 'Guest Diagnosis Session'
        : (profile?['email'] as String?) ?? '';
    final headerLetter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G';
    final profilePicture = (profile?['profile_picture'] as String?) ?? '';

    return Drawer(
      backgroundColor: scheme.surface,
      child: Column(
        children: [
          // Header
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryColor, AppTheme.primaryDark],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: _buildProfileImage(profilePicture),
              child: _buildProfileImage(profilePicture) == null
                  ? Text(
                      headerLetter,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : null,
            ),
            accountName: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(displayEmail),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: isGuest
                  ? const []
                  : isAdmin
                      ? _adminMenuItems(context)
                      : _customerMenuItems(context),
            ),
          ),

          // Logout
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.dangerColor),
            title: Text(
              context.tr('Keluar', 'Logout'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppTheme.dangerColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: () async {
              final navigator = Navigator.of(context);
              final auth = context.read<AuthProvider>();

              navigator.pop();
              if (isGuest) {
                navigator.pushNamedAndRemoveUntil('/login', (r) => false);
                return;
              }

              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(context.tr('Keluar', 'Logout')),
                  content: Text(context
                      .tr('Keluar dari akun?', 'Log out from this account?')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(context.tr('Batal', 'Cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(context.tr('Keluar', 'Logout')),
                    ),
                  ],
                ),
              );

              if (confirmed ?? false) {
                await auth.logout();
                navigator.pushNamedAndRemoveUntil(
                  '/login',
                  (r) => false,
                  arguments: isAdmin ? {'role': 'admin'} : {'role': 'customer'},
                );
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  ImageProvider<Object>? _buildProfileImage(String pathOrUrl) {
    if (pathOrUrl.isEmpty) return null;
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return NetworkImage(pathOrUrl);
    }

    final file = File(pathOrUrl);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  List<Widget> _adminMenuItems(BuildContext context) {
    return [
      _buildMenuItem(context, Icons.dashboard, context.tr('Dashboard', 'Dashboard'), '/admin/dashboard'),
      _buildMenuItem(
        context, Icons.calendar_today, context.tr('Booking', 'Bookings'), '/admin/bookings'),
      _buildMenuItem(context, Icons.build, context.tr('Servis', 'Services'), '/admin/services'),
      _buildMenuItem(context, Icons.people, context.tr('Pelanggan', 'Customers'), '/admin/customers'),
      _buildMenuItem(
        context, Icons.account_balance_wallet, context.tr('Keuangan', 'Finance'), '/admin/finance'),
      _buildMenuItem(
        context, Icons.inventory, context.tr('Spare Part', 'Spare Parts'), '/admin/spare-parts'),
      _buildMenuItem(context, Icons.point_of_sale, context.tr('PPOB', 'PPOB'), '/admin/counter'),
      _buildMenuItem(
        context, Icons.store, context.tr('Pengaturan Toko', 'Store Settings'), '/admin/store-settings'),
      _buildMenuItem(context, Icons.settings, context.tr('Pengaturan', 'Settings'), '/admin/settings'),
    ];
  }

  List<Widget> _customerMenuItems(BuildContext context) {
    return [
      _buildMenuItem(
        context, Icons.dashboard, context.tr('Dashboard', 'Dashboard'), '/customer/dashboard'),
      _buildMenuItem(
        context, Icons.add_circle, context.tr('Booking Servis', 'Service Booking'), '/customer/booking'),
      _buildMenuItem(
        context, Icons.medical_services, context.tr('Diagnosis', 'Diagnosis'), '/customer/diagnosis'),
      _buildMenuItem(
        context, Icons.track_changes, context.tr('Status Servis', 'Service Status'), '/customer/status'),
      _buildMenuItem(context, Icons.history, context.tr('Riwayat', 'History'), '/customer/history'),
      _buildMenuItem(context, Icons.person, context.tr('Profil', 'Profile'), '/customer/profile'),
      _buildMenuItem(
        context, Icons.settings, context.tr('Pengaturan', 'Settings'), '/customer/settings'),
    ];
  }

  Widget _buildMenuItem(
      BuildContext context, IconData icon, String title, String route) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isActive = currentRoute == route;
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListTile(
      leading: Icon(icon, color: isActive ? AppTheme.primaryColor : mutedColor),
      title: Text(
        title,
        style: TextStyle(
          color: isActive
              ? AppTheme.primaryColor
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isActive,
      selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: () {
        Navigator.pop(context);
        if (isActive) return;

        final dashboardRoute = isAdmin
            ? '/admin/dashboard'
            : '/customer/dashboard';
        if (route == dashboardRoute) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            route,
            (r) => r.settings.name == '/auth-wrapper',
          );
          return;
        }

        Navigator.pushNamedAndRemoveUntil(
          context,
          route,
          (r) =>
              r.settings.name == '/auth-wrapper' ||
              r.settings.name == dashboardRoute,
        );
      },
    );
  }
}
