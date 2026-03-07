import '../config/api_config.dart';
import '../models/notification.dart';
import 'api_service.dart';

class NotificationService {
  /// Get all notifications for current user
  static Future<Map<String, dynamic>> getNotifications() async {
    final response = await ApiService.get(ApiConfig.notifications);
    if (response.success) {
      final data = response.dataMap;
      final list = data['notifications'] ?? data['data'] ?? [];
      final unreadCount =
          int.tryParse(data['unread_count']?.toString() ?? '0') ?? 0;
      return {
        'notifications': (list as List)
            .map((e) => AppNotification.fromJson(e))
            .toList(),
        'unread_count': unreadCount,
      };
    }
    return {'notifications': <AppNotification>[], 'unread_count': 0};
  }

  /// Mark single notification as read
  static Future<ApiResponse> markAsRead(int notificationId) async {
    return await ApiService.post(
      '${ApiConfig.notifications}?action=mark_read',
      body: {'notification_id': notificationId},
    );
  }

  /// Mark all notifications as read
  static Future<ApiResponse> markAllAsRead() async {
    return await ApiService.post(
      '${ApiConfig.notifications}?action=mark_all_read',
    );
  }

  /// Approve password request (admin)
  static Future<ApiResponse> approvePasswordRequest(int requestId) async {
    return await ApiService.post(
      '${ApiConfig.notifications}?action=approve_password',
      body: {'request_id': requestId},
    );
  }

  /// Reject password request (admin)
  static Future<ApiResponse> rejectPasswordRequest(
      int requestId, String? notes) async {
    return await ApiService.post(
      '${ApiConfig.notifications}?action=reject_password',
      body: {
        'request_id': requestId,
        if (notes != null) 'notes': notes,
      },
    );
  }
}
