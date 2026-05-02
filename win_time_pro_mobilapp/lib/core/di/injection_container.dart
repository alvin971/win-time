import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/dio_client.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/orders/data/datasources/orders_remote_datasource.dart';
import '../../features/orders/data/repositories/order_repository_impl.dart';
import '../../features/orders/domain/repositories/order_repository.dart';

/// Registre de dépendances manuel pour Win Time Pro
/// (pas d'injectable/get_it — instanciation explicite pour visibilité maximale)
class ServiceLocator {
  ServiceLocator._();

  static late FlutterSecureStorage _secureStorage;
  static late DioClient _dioClient;
  static late WebSocketService _wsService;
  static late NotificationService _notificationService;

  // Auth
  static late AuthLocalDataSource _authLocal;
  static late AuthRemoteDataSource _authRemote;
  static late AuthRepository authRepository;

  // Orders
  static late OrdersRemoteDataSource _ordersRemote;
  static late OrderRepository orderRepository;

  /// À appeler une seule fois dans main() avant runApp()
  ///
  /// IMPORTANT : on initialise les fields CRITIQUES (authRepository,
  /// orderRepository) AVANT tout call Firebase. Comme ça, même si Firebase
  /// throw (parce que GoogleService-Info.plist est absent), les BlocProvider
  /// qui dépendent de ServiceLocator.authRepository peuvent toujours se
  /// construire et l'app affiche au moins la SplashScreen au lieu d'écran blanc.
  static Future<void> init() async {
    // ─── 1. Infrastructure (toujours OK, pas d'I/O réseau) ────────────────
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

    _dioClient = DioClient(secureStorage: _secureStorage);
    _wsService = WebSocketService();

    // ─── 2. Auth (DOIT être set avant runApp pour que BlocProvider build) ─
    _authLocal = AuthLocalDataSourceImpl(_secureStorage);
    _authRemote = AuthRemoteDataSourceImpl(_dioClient);
    authRepository = AuthRepositoryImpl(
      remote: _authRemote,
      local: _authLocal,
      dioClient: _dioClient,
    );

    // ─── 3. Orders ────────────────────────────────────────────────────────
    _ordersRemote = OrdersRemoteDataSourceImpl(_dioClient);
    orderRepository = OrderRepositoryImpl(
      remote: _ordersRemote,
      wsService: _wsService,
    );

    // ─── 4. NotificationService (lazy Firebase, ne throw plus) ────────────
    _notificationService = NotificationService();

    // ─── 5. Firebase optionnel (peut hang/throw, mais tout est déjà set) ──
    try {
      // Le constructeur NotificationService est désormais safe (lazy + try/catch).
      // Ici on tente juste de récupérer le token initial pour le backend.
      final fcmToken = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (fcmToken != null) {
        _notificationService.onTokenRefreshed = (token) {
          // TODO: POST /notifications/fcm-token via _dioClient
        };
      }
    } catch (e) {
      debugPrint('ServiceLocator: Firebase token unavailable: $e');
    }
  }

  // Accès aux singletons partagés
  static DioClient get dioClient => _dioClient;
  static WebSocketService get wsService => _wsService;
  static NotificationService get notificationService => _notificationService;
  static FlutterSecureStorage get secureStorage => _secureStorage;
}
