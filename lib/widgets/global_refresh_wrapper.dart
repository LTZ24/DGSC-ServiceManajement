import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/backend_service.dart';
import '../services/diagnosis_config_service.dart';

class GlobalRefreshWrapper extends StatefulWidget {
  final Widget child;

  const GlobalRefreshWrapper({
    super.key,
    required this.child,
  });

  @override
  State<GlobalRefreshWrapper> createState() => _GlobalRefreshWrapperState();
}

class _GlobalRefreshWrapperState extends State<GlobalRefreshWrapper> {
  static const Set<String> _excludedRoutes = {
    '/customer/dashboard',
    '/admin/dashboard',
  };

  Future<void> _handleRefresh() async {
    try {
      if (BackendService.currentUser != null) {
        await context.read<AuthProvider>().checkAuth();
      }
      await DiagnosisConfigService.syncPublishedDataset();
    } catch (_) {
      // Ignore refresh errors and keep UI responsive.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (pageContext) => RefreshIndicator.adaptive(
        onRefresh: _handleRefresh,
        notificationPredicate: (notification) {
          final notificationContext = notification.context;
          final routeName = notificationContext != null
              ? ModalRoute.of(notificationContext)?.settings.name
              : ModalRoute.of(pageContext)?.settings.name;
          if (_excludedRoutes.contains(routeName)) {
            return false;
          }

          return notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical;
        },
        child: widget.child,
      ),
    );
  }
}
