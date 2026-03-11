import 'package:flutter/material.dart';
import '../l10n/app_text.dart';
import '../config/theme.dart';
import '../services/backend_service.dart';
import '../services/backend_types.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = BackendService.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: () {},
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BackendService.notificationsStream(uid),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final unreadCount = docs.where((doc) {
          final isRead = doc.data()['is_read'];
          return isRead != true;
        }).length;

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => _showNotifications(context),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.dangerColor,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _NotificationSheet(),
    );
  }
}

class _NotificationSheet extends StatefulWidget {
  const _NotificationSheet();

  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  Future<void> _markAllRead() async {
    final uid = BackendService.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    await BackendService.markAllNotificationsRead(uid);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        final uid = BackendService.currentUser?.uid;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: uid == null || uid.isEmpty
              ? const Stream.empty()
              : BackendService.notificationsStream(uid),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? const [];
            final unreadCount = docs.where((doc) {
              final isRead = doc.data()['is_read'];
              return isRead != true;
            }).length;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('Notifikasi', 'Notifications'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton(
                        onPressed: unreadCount == 0 ? null : _markAllRead,
                        child: Text(context.tr('Tandai Semua Dibaca', 'Mark All as Read')),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : snapshot.hasError
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  context.tr('Gagal memuat notifikasi. Coba lagi nanti.', 'Failed to load notifications. Please try again later.'),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : docs.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.notifications_off_outlined,
                                          size: 48, color: Colors.grey),
                                      const SizedBox(height: 8),
                                      Text(context.tr('Tidak ada notifikasi', 'No notifications'),
                                          style: const TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final notif = docs[index].data();
                                    final isRead = notif['is_read'] == true;
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isRead
                                            ? Colors.grey.shade200
                                            : AppTheme.primaryColor
                                                .withValues(alpha: 0.1),
                                        child: Icon(
                                          _getNotifIcon(
                                              notif['type']?.toString() ?? ''),
                                          color: isRead
                                              ? Colors.grey
                                              : AppTheme.primaryColor,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        notif['title']?.toString() ?? '-',
                                        style: TextStyle(
                                          fontWeight: isRead
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        notif['message']?.toString() ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onTap: () async {
                                        await BackendService.markNotificationRead(
                                          docs[index].id,
                                        );
                                      },
                                    );
                                  },
                                ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getNotifIcon(String type) {
    switch (type) {
      case 'booking':
        return Icons.calendar_today;
      case 'service':
        return Icons.build;
      case 'payment':
        return Icons.payment;
      case 'password':
        return Icons.lock;
      default:
        return Icons.notifications;
    }
  }
}
