import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

// Top-level background handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by main() before this is called
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'daily_outfit';
  static const _channelName = 'Daily Outfit Suggestions';
  static const _channelDesc = 'Your personalised daily outfit recommendation';

  static const _androidChannel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.high,
  );

  Future<void> init() async {
    // 1. Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Permission denied');
      return;
    }

    // 2. Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // 3. Initialise local notifications (displays FCM while app is foreground)
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false, // already requested above
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // 4. Save initial token
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);

    // 5. Refresh token listener
    _messaging.onTokenRefresh.listen(_saveToken);

    // 6. Foreground messages → show as local notification
    FirebaseMessaging.onMessage.listen(_showForeground);

    // 7. Background tap (app was suspended)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);

    // 8. Cold-start tap (app was terminated)
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleOpen(initial);
  }

  Future<void> _saveToken(String token) async {
    debugPrint('[FCM] Token: ${token.substring(0, 20)}...');
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    try {
      await http.post(
        Uri.parse('${SupabaseConfig.apiBaseUrl}/api/v1/notifications/token'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': token}),
      );
    } catch (e) {
      debugPrint('[FCM] Token save failed: $e');
    }
  }

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _localNotifications.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['type'],
    );
  }

  void _handleOpen(RemoteMessage message) {
    debugPrint('[FCM] Opened from notification: ${message.data}');
    _routeFromData(message.data);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('[FCM] Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      _routeFromData({'type': response.payload});
    }
  }

  /// Notifier that MainShell observes to switch tabs.
  /// Value: tab index to switch to (0=Closet,1=Outfits,2=Stylist,3=Discover,4=Profile).
  static final tabNotifier = ValueNotifier<int?>(null);

  void _routeFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'photo_ready':
      case 'forgotten_garment':
        tabNotifier.value = 0;   // Closet
        break;
      case 'outfit_saved':
        tabNotifier.value = 1;   // Outfits
        break;
      case 'daily_outfit':
        tabNotifier.value = 2;   // Stylist
        break;
      case 'weekly_insight':
        tabNotifier.value = 3;   // Discover
        break;
      default:
        break;
    }
  }

  /// Call after login to (re-)register the token with the backend
  Future<void> onLogin() async {
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
  }

  /// Call on logout to stop sending notifications to this device
  Future<void> onLogout() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    try {
      await http.delete(
        Uri.parse('${SupabaseConfig.apiBaseUrl}/api/v1/notifications/token'),
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
    } catch (_) {}
  }
}
