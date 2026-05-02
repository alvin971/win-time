import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

/// Service de gestion des notifications push
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
    // Configuration des notifications locales (Android)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuration des notifications locales (iOS)
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

    // Demander la permission pour iOS
    await _requestPermission();

    // Récupérer le token FCM (timeout obligatoire — sans GoogleService-Info.plist
    // ce call peut hanger indéfiniment au lieu de throw).
    final token = await _firebaseMessaging
        .getToken()
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    print('FCM Token: $token');

    // Écouter les messages en foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Écouter les messages qui ouvrent l'app
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
      print('Notification permissions granted');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('Notification permissions granted provisionally');
    } else {
      print('Notification permissions denied');
    }
  }

  /// Gère les messages reçus en foreground
  void _handleForegroundMessage(RemoteMessage message) {
    print('Message reçu en foreground: ${message.messageId}');

    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      _showLocalNotification(
        title: notification.title ?? 'Win Time',
        body: notification.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Gère les messages qui ouvrent l'application
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Message opened app: ${message.messageId}');
    // Navigation vers la page appropriée selon message.data
    _handleNotificationData(message.data);
  }

  /// Affiche une notification locale
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

  /// Callback quand une notification est tappée
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Navigation selon le payload
  }

  /// Traite les données de notification pour navigation
  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final orderId = data['order_id'] as String?;

    switch (type) {
      case 'order_status_update':
        // Naviguer vers la page de détail de commande
        print('Navigate to order: $orderId');
        break;
      case 'order_ready':
        // Notification que la commande est prête
        print('Order ready: $orderId');
        break;
      default:
        print('Unknown notification type: $type');
    }
  }

  /// S'abonner à un topic (ex: pour les restaurants)
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  /// Se désabonner d'un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }

  /// Récupérer le token FCM (avec timeout 5s pour éviter les hangs)
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
