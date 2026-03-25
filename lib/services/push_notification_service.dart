import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_log_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'dgsc_general_notifications',
    'DGSC Notifications',
    description: 'Notifikasi booking, servis, dan pembayaran.',
    importance: Importance.high,
  );

  static bool _initialized = false;
  static const _permissionsPromptPrefix = 'initial_permissions_prompted_';
  static const _initialAppPermissionsKey = 'initial_app_permissions_prompted';

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

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(AppLogService.log(
        'Push notification opened: ${_messageLogLabel(message)}',
      ));
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await AppLogService.log(
        'Push notification opened from terminated state: ${_messageLogLabel(initialMessage)}',
      );
    }

    final token = await _messaging.getToken();
    await AppLogService.log(
      token == null || token.isEmpty
          ? 'FCM token unavailable during initialization'
          : 'FCM token initialized successfully',
    );

    _initialized = true;
  }


  static Future<void> requestInitialAppPermissions() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_initialAppPermissionsKey) == true) return;

    await _requestPermissionIfNeeded(Permission.storage);
    await _requestPermissionIfNeeded(Permission.camera);
    final notificationGranted =
        await _requestPermissionIfNeeded(Permission.notification);
    if (notificationGranted) {
      await _ensureRemoteMessagingReady();
    }

    await prefs.setBool(_initialAppPermissionsKey, true);
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

    if (!context.mounted) return;

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
      await _ensureRemoteMessagingReady();
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

  static Future<bool> _requestPermissionIfNeeded(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) return false;
    if (status.isDenied || status.isRestricted || status.isLimited) {
      final result = await permission.request();
      return result.isGranted || result.isLimited;
    }
    return false;
  }

  static Future<void> _ensureRemoteMessagingReady() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final token = await _messaging.getToken();
    await AppLogService.log(
      token == null || token.isEmpty
          ? 'FCM token still unavailable after permission grant'
          : 'FCM token ready after permission grant',
    );
  }

  static Future<void> syncTopicSubscriptions({
    String? userId,
    String? role,
  }) async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final previousUserId = prefs.getString('push_user_id');
    final previousRole = prefs.getString('push_user_role');

    if (previousUserId != null &&
        previousUserId.isNotEmpty &&
        previousUserId != userId) {
      await _messaging.unsubscribeFromTopic('user_$previousUserId');
    }
    if (previousRole != null &&
        previousRole.isNotEmpty &&
        previousRole != role) {
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
    final title = _resolveTitle(message);
    final body = _resolveBody(message);
    if (body.isEmpty) {
      await AppLogService.log(
        'Foreground push ignored because payload body is empty: ${_messageLogLabel(message)}',
      );
      return;
    }

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          channelAction: AndroidNotificationChannelAction.createIfNotExists,
        ),
      ),
    );
    await AppLogService.log(
      'Foreground push displayed: ${_messageLogLabel(message)}',
    );
  }

  static String _resolveTitle(RemoteMessage message) {
    final notificationTitle = message.notification?.title?.trim() ?? '';
    final dataTitle = message.data['title']?.toString().trim() ?? '';
    if (notificationTitle.isNotEmpty) return notificationTitle;
    if (dataTitle.isNotEmpty) return dataTitle;
    return 'Notifikasi DGSC';
  }

  static String _resolveBody(RemoteMessage message) {
    final notificationBody = message.notification?.body?.trim() ?? '';
    final dataBody = message.data['message']?.toString().trim() ??
        message.data['body']?.toString().trim() ??
        '';
    if (notificationBody.isNotEmpty) return notificationBody;
    return dataBody;
  }

  static String _messageLogLabel(RemoteMessage message) {
    final source = Platform.isAndroid ? 'android' : 'mobile';
    return '$source | ${_resolveTitle(message)}';
  }
}
