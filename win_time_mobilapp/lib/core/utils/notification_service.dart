import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

/// Service de gestion des notifications push.
///
/// All logging goes through `debugPrint` so release builds stay quiet — raw
/// `print()` would leak the FCM token and notification payloads to device
/// syslog (audit S2.2.12 / S8.2.8).
@singleton
class NotificationService {
  final FirebaseMessaging _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  NotificationService(
    this._firebaseMessaging,
    this._localNotifications,
  );

  /// Initialise le service de notifications
  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _requestPermission();

    // Récupérer le token FCM (timeout obligatoire — sans GoogleService-Info.plist
    // ce call peut hang indéfiniment au lieu de throw).
    final token = await _firebaseMessaging
        .getToken()
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    // Never log the full FCM token in release. Mask in debug to keep logs grep-safe.
    debugPrint(
      'FCM Token (masked): ${token == null ? '<null>' : '${token.substring(0, 8)}…'}',
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  /// Demande la permission pour les notifications (iOS)
  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Notification permissions granted');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('Notification permissions granted provisionally');
    } else {
      debugPrint('Notification permissions denied');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Message reçu en foreground: ${message.messageId}');

    final notification = message.notification;
    if (notification != null) {
      _showLocalNotification(
        title: notification.title ?? 'Win Time',
        body: notification.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened app: ${message.messageId}');
    _handleNotificationData(message.data);
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'win_time_channel',
      'Win Time Notifications',
      channelDescription: 'Notifications pour les commandes Win Time',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final orderId = data['order_id'] as String?;

    switch (type) {
      case 'order_status_update':
        debugPrint('Navigate to order: $orderId');
        break;
      case 'order_ready':
        debugPrint('Order ready: $orderId');
        break;
      default:
        debugPrint('Unknown notification type: $type');
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }

  Future<String?> getToken() async {
    try {
      return await _firebaseMessaging
          .getToken()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }
}
