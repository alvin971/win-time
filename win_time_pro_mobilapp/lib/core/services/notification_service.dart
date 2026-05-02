import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service de gestion des notifications push (Firebase).
///
/// IMPORTANT : `FirebaseMessaging.instance` throw `[core/no-app]` quand
/// `Firebase.initializeApp()` n'a pas été appelé (ou quand GoogleService-Info.plist
/// est absent). On lazy-load + null-guard tous les usages pour que le
/// constructeur n'explose pas — l'app démarre même sans Firebase, les
/// notifications push sont juste désactivées.
class NotificationService {
  FirebaseMessaging? _firebaseMessagingCache;
  bool _firebaseAttempted = false;

  FirebaseMessaging? get _fcm {
    if (_firebaseAttempted) return _firebaseMessagingCache;
    _firebaseAttempted = true;
    try {
      _firebaseMessagingCache = FirebaseMessaging.instance;
    } catch (e) {
      debugPrint('NotificationService: FirebaseMessaging unavailable: $e');
      _firebaseMessagingCache = null;
    }
    return _firebaseMessagingCache;
  }

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
    final fcm = _fcm;

    // Permissions push (FCM)
    if (fcm != null) {
      try {
        await _requestPermission(fcm);
      } catch (e) {
        debugPrint('NotificationService: requestPermission failed: $e');
      }
    }

    // Configuration des notifications locales (toujours OK même sans Firebase)
    await _configureLocalNotifications();

    if (fcm != null) {
      try {
        // Token FCM avec timeout obligatoire (sinon hang sans GoogleService-Info.plist)
        _fcmToken = await fcm
            .getToken()
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        debugPrint('📱 FCM Token: $_fcmToken');

        fcm.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          onTokenRefreshed?.call(newToken);
        });

        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        final initialMessage = await fcm
            .getInitialMessage()
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      } catch (e) {
        debugPrint('NotificationService: Firebase setup failed: $e');
      }
    }
  }

  /// Demander les permissions de notifications
  Future<void> _requestPermission(FirebaseMessaging fcm) async {
    final settings = await fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('📬 Notification permission: ${settings.authorizationStatus}');
  }

  /// Configuration des notifications locales (affichage personnalisé)
  Future<void> _configureLocalNotifications() async {
    // Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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
    debugPrint('🔔 Foreground message: ${message.messageId}');

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
    debugPrint('🚀 App opened from notification: ${message.messageId}');

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
    final fcm = _fcm;
    if (fcm == null) return;
    try {
      await fcm.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('NotificationService: subscribeToTopic failed: $e');
    }
  }

  /// Se désabonner d'un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    final fcm = _fcm;
    if (fcm == null) return;
    try {
      await fcm.unsubscribeFromTopic(topic);
      debugPrint('❌ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('NotificationService: unsubscribeFromTopic failed: $e');
    }
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
