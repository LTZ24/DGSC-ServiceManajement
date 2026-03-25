import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../l10n/app_text.dart';
import '../providers/auth_provider.dart';

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
    final headerActions = <_DrawerHeaderAction>[
      if (isAdmin && !isGuest)
        _DrawerHeaderAction(
          icon: Icons.storefront_outlined,
          route: '/admin/store-settings',
          tooltip: context.tr('Pengaturan Toko', 'Store Settings'),
        ),
      if (!isGuest)
        _DrawerHeaderAction(
          icon: Icons.settings_rounded,
          route: isAdmin ? '/admin/settings' : '/customer/settings',
          tooltip: context.tr('Pengaturan', 'Settings'),
        ),
    ];

    return Drawer(
      backgroundColor: scheme.surface,
      child: Column(
        children: [
          _DrawerHeader(
            displayName: displayName,
            displayEmail: displayEmail,
            headerLetter: headerLetter,
            profileImage: _buildProfileImage(profilePicture),
            actions: headerActions,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              children: isGuest
                  ? const []
                  : isAdmin
                      ? _adminMenuItems(context)
                      : _customerMenuItems(context),
            ),
          ),
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
                navigator.pushNamedAndRemoveUntil(
                  '/login',
                  (r) => false,
                  arguments: {'role': 'customer'},
                );
                return;
              }

              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(context.tr('Keluar', 'Logout')),
                  content: Text(
                    context.tr('Keluar dari akun?', 'Log out from this account?'),
                  ),
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
      _buildMenuItem(context, Icons.calendar_today, context.tr('Booking', 'Bookings'), '/admin/bookings'),
      _buildMenuItem(context, Icons.build, context.tr('Servis', 'Services'), '/admin/services'),
      _buildMenuItem(context, Icons.people, context.tr('Pelanggan', 'Customers'), '/admin/customers'),
      _buildMenuItem(context, Icons.account_balance_wallet, context.tr('Keuangan', 'Finance'), '/admin/finance'),
      _buildMenuItem(context, Icons.inventory, context.tr('Spare Part', 'Spare Parts'), '/admin/spare-parts'),
      _buildMenuItem(context, Icons.receipt_long, context.tr('PPOB', 'PPOB'), '/admin/counter'),
      _buildMenuItem(context, Icons.point_of_sale, context.tr('Kasir', 'Cashier'), '/admin/cashier'),
    ];
  }

  List<Widget> _customerMenuItems(BuildContext context) {
    return [
      _buildMenuItem(context, Icons.dashboard, context.tr('Dashboard', 'Dashboard'), '/customer/dashboard'),
      _buildMenuItem(context, Icons.add_circle, context.tr('Booking Servis', 'Service Booking'), '/customer/booking'),
      _buildMenuItem(context, Icons.medical_services, context.tr('Diagnosis', 'Diagnosis'), '/customer/diagnosis'),
      _buildMenuItem(context, Icons.track_changes, context.tr('Status Servis', 'Service Status'), '/customer/status'),
      _buildMenuItem(context, Icons.history, context.tr('Riwayat', 'History'), '/customer/history'),
      _buildMenuItem(context, Icons.person, context.tr('Profil', 'Profile'), '/customer/profile'),
    ];
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String route,
  ) {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: () {
        Navigator.pop(context);
        if (isActive) return;

        final dashboardRoute = isAdmin ? '/admin/dashboard' : '/customer/dashboard';
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

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.displayName,
    required this.displayEmail,
    required this.headerLetter,
    required this.profileImage,
    required this.actions,
  });

  final String displayName;
  final String displayEmail;
  final String headerLetter;
  final ImageProvider<Object>? profileImage;
  final List<_DrawerHeaderAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, AppTheme.primaryDark],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  backgroundImage: profileImage,
                  child: profileImage == null
                      ? Text(
                          headerLetter,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : null,
                ),
                const Spacer(),
                if (actions.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: actions.map((action) {
                      return IconButton(
                        onPressed: () {
                          final currentRoute =
                              ModalRoute.of(context)?.settings.name;
                          final navigator = Navigator.of(context);
                          navigator.pop();
                          if (currentRoute == action.route) return;
                          navigator.pushNamed(action.route);
                        },
                        tooltip: action.tooltip,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.14),
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(action.icon),
                      );
                    }).toList(),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              displayEmail,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeaderAction {
  const _DrawerHeaderAction({
    required this.icon,
    required this.route,
    required this.tooltip,
  });

  final IconData icon;
  final String route;
  final String tooltip;
}
