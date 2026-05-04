import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/dio_client.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/datasources/supabase_auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/orders/data/datasources/orders_remote_datasource.dart';
import '../../features/orders/data/datasources/supabase_orders_datasource.dart';
import '../../features/orders/data/repositories/order_repository_impl.dart';
import '../../features/orders/domain/repositories/order_repository.dart';
import '../../features/profile/data/datasources/supabase_restaurant_datasource.dart';

/// Registre de dépendances manuel pour Win Time Pro
/// (pas d'injectable/get_it — instanciation explicite pour visibilité maximale).
///
/// Backend : Supabase auto-hosté (https://supabase.0for0.com), schéma `wintime`.
/// DioClient et WebSocketService sont conservés pour compat avec
/// NotificationService et le code legacy ; ils ne sont plus utilisés par
/// les datasources Auth/Orders qui passent désormais par Supabase directement.
class ServiceLocator {
  ServiceLocator._();

  static late SupabaseClient _supabase;
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

  // Pro-only — datasource Supabase exposé directement
  // (pour récupérer "mon restaurant" + abonner les streams realtime).
  static late SupabaseOrdersDataSource ordersDataSource;
  static late SupabaseRestaurantDataSource restaurantDataSource;

  /// Restaurant ID du commerçant connecté (set par le SplashPage/AuthBloc
  /// après login, lu par le DashboardPage). Null si user pas commerçant ou
  /// pas encore login.
  static String? currentRestaurantId;

  /// À appeler une seule fois dans main() avant runApp().
  /// IMPORTANT : Supabase.initialize doit avoir été appelé AVANT.
  static Future<void> init() async {
    // ─── 1. Supabase client (singleton initialisé par Supabase.initialize) ─
    _supabase = Supabase.instance.client;

    // ─── 2. Infrastructure ────────────────────────────────────────────────
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    _dioClient = DioClient(secureStorage: _secureStorage);
    _wsService = WebSocketService();

    // ─── 3. Auth (Supabase backend) ───────────────────────────────────────
    _authLocal = AuthLocalDataSourceImpl(_secureStorage);
    _authRemote = SupabaseAuthRemoteDataSource(_supabase);
    authRepository = AuthRepositoryImpl(
      remote: _authRemote,
      local: _authLocal,
      dioClient: _dioClient, // legacy : utilisé pour setAuthToken (no-op effectif)
    );

    // ─── 4. Orders (Supabase backend) ─────────────────────────────────────
    ordersDataSource = SupabaseOrdersDataSource(_supabase);
    _ordersRemote = ordersDataSource;
    orderRepository = OrderRepositoryImpl(
      remote: _ordersRemote,
      wsService: _wsService,
    );

    // ─── 5. Restaurant (Supabase, lectures + futures écritures) ───────────
    restaurantDataSource = SupabaseRestaurantDataSource(_supabase);

    // ─── 6. NotificationService (lazy Firebase, ne throw plus) ────────────
    _notificationService = NotificationService();

    // ─── 7. Firebase optionnel (FCM seulement, peut hang/throw) ───────────
    try {
      final fcmToken = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (fcmToken != null) {
        _notificationService.onTokenRefreshed = (token) {
          // TODO: persister via Supabase wintime.user_profiles.fcm_token
          if (kDebugMode) debugPrint('FCM token refreshed: $token');
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ServiceLocator: Firebase token unavailable: $e');
    }
  }

  /// Met à jour le restaurantId courant après login (appelé par SplashPage
  /// ou par un listener sur l'AuthBloc).
  static Future<void> resolveCurrentRestaurantId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      currentRestaurantId = null;
      return;
    }
    try {
      currentRestaurantId =
          await restaurantDataSource.getMyRestaurantId(user.id);
    } catch (e) {
      if (kDebugMode) debugPrint('resolveCurrentRestaurantId failed: $e');
      currentRestaurantId = null;
    }
  }

  /// Reset après logout.
  static void clearSession() {
    currentRestaurantId = null;
  }

  // Accès aux singletons partagés
  static SupabaseClient get supabase => _supabase;
  static DioClient get dioClient => _dioClient;
  static WebSocketService get wsService => _wsService;
  static NotificationService get notificationService => _notificationService;
  static FlutterSecureStorage get secureStorage => _secureStorage;
}
