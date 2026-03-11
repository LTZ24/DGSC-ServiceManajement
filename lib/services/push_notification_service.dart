import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'dgsc_general_notifications',
    'DGSC Notifications',
    description: 'Notifikasi booking, servis, dan pembayaran.',
    importance: Importance.high,
  );

  static bool _initialized = false;
  static const _permissionsPromptPrefix = 'initial_permissions_prompted_';

  static Future<void> initialize() async {
    if (_initialized) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);
    await _messaging.setAutoInitEnabled(true);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    _initialized = true;
  }

  static Future<void> requestFirstLoginPermissions(
    BuildContext context, {
    required String? userId,
    required String role,
  }) async {
    if (userId == null || userId.isEmpty || !context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_permissionsPromptPrefix$userId';
    final existingStatus = await Permission.notification.status;
    if (existingStatus.isGranted || existingStatus.isLimited) {
      await prefs.setBool(storageKey, true);
      await _messaging.getToken();
      await syncTopicSubscriptions(userId: userId, role: role);
      return;
    }

    if (prefs.getBool(storageKey) == true) return;

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Izin Aplikasi'),
        content: const Text(
          'Aplikasi membutuhkan izin notifikasi agar update booking, servis, dan pembayaran bisa masuk ke perangkat Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Nanti'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Izinkan'),
          ),
        ],
      ),
    );

    await prefs.setBool(storageKey, true);
    if (approved != true) return;

    final notificationStatus = await Permission.notification.request();
    if (notificationStatus.isGranted) {
      await _messaging.getToken();
      await syncTopicSubscriptions(userId: userId, role: role);
    } else if (notificationStatus.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  static Future<void> markPermissionPromptHandled(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_permissionsPromptPrefix$userId', true);
  }

  static Future<void> syncTopicSubscriptions({
    String? userId,
    String? role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final previousUserId = prefs.getString('push_user_id');
    final previousRole = prefs.getString('push_user_role');

    if (previousUserId != null &&
        previousUserId.isNotEmpty &&
        previousUserId != userId) {
      await _messaging.unsubscribeFromTopic('user_$previousUserId');
    }
    if (previousRole != null && previousRole.isNotEmpty && previousRole != role) {
      await _messaging.unsubscribeFromTopic('role_$previousRole');
    }

    if (userId == null || userId.isEmpty) {
      await prefs.remove('push_user_id');
      await prefs.remove('push_user_role');
      return;
    }

    await _messaging.subscribeToTopic('user_$userId');
    await prefs.setString('push_user_id', userId);

    if (role != null && role.isNotEmpty) {
      await _messaging.subscribeToTopic('role_$role');
      await prefs.setString('push_user_role', role);
    } else {
      await prefs.remove('push_user_role');
    }

    await _messaging.getToken();
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}
