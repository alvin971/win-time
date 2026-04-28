import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;

/// Service de gestion des notifications push (Firebase)
/// Gère les notifications en foreground, background et terminated
class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Callback appelé quand l'utilisateur tape sur une notification
  Function(Map<String, dynamic>)? onNotificationTap;

  /// Callback appelé quand le token FCM est renouvelé
  /// À brancher sur POST /notifications/fcm-token dans le DI
  Function(String token)? onTokenRefreshed;

  /// Initialisation du service
  Future<void> initialize() async {
    // Demander les permissions
    await _requestPermission();

    // Configuration des notifications locales
    await _configureLocalNotifications();

    // Récupérer le token FCM
    _fcmToken = await _firebaseMessaging.getToken();
    print('📱 FCM Token: $_fcmToken');

    // Écouter les changements de token et notifier le backend
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      onTokenRefreshed?.call(newToken);
    });

    // Gérer les messages en foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Gérer les messages qui ouvrent l'app (background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Vérifier si l'app a été ouverte via une notification
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  /// Demander les permissions de notifications
  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('📬 Notification permission: ${settings.authorizationStatus}');
  }

  /// Configuration des notifications locales (affichage personnalisé)
  Future<void> _configureLocalNotifications() async {
    // Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: (id, title, body, payload) {
        // iOS < 10 (legacy)
      },
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Quand l'utilisateur tape sur une notification locale
        if (details.payload != null) {
          final data = _parsePayload(details.payload!);
          onNotificationTap?.call(data);
        }
      },
    );

    // Canal Android pour les commandes (haute priorité)
    const androidChannel = AndroidNotificationChannel(
      'orders',
      'Commandes',
      description: 'Notifications pour les nouvelles commandes',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Gérer les messages reçus en foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('🔔 Foreground message: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      // Afficher une notification locale
      await _showLocalNotification(
        title: notification.title ?? 'Win Time Pro',
        body: notification.body ?? '',
        payload: _stringifyData(data),
        type: data['type'] ?? 'default',
      );
    }
  }

  /// Gérer les messages qui ouvrent l'app
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('🚀 App opened from notification: ${message.messageId}');

    final data = message.data;
    onNotificationTap?.call(data);
  }

  /// Afficher une notification locale
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
    required String type,
  }) async {
    // Déterminer l'importance selon le type
    final importance = type == 'new_order'
        ? Importance.max
        : Importance.defaultImportance;

    final androidDetails = AndroidNotificationDetails(
      'orders',
      'Commandes',
      channelDescription: 'Notifications pour les commandes',
      importance: importance,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: type == 'new_order', // Affichage plein écran pour nouvelles commandes
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// S'abonner à un topic (ex: restaurant spécifique)
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    print('✅ Subscribed to topic: $topic');
  }

  /// Se désabonner d'un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print('❌ Unsubscribed from topic: $topic');
  }

  /// Helpers pour payload
  String _stringifyData(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  Map<String, dynamic> _parsePayload(String payload) {
    final map = <String, dynamic>{};
    final pairs = payload.split('&');
    for (final pair in pairs) {
      final idx = pair.indexOf('=');
      if (idx > 0) {
        map[pair.substring(0, idx)] = pair.substring(idx + 1);
      }
    }
    return map;
  }
}
