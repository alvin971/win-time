import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../services/websocket_service.dart';
import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
Future<void> configureDependencies() async {
  // ─── Plugins natifs (toujours OK) ─────────────────────────────────────
  getIt.registerSingleton<FlutterLocalNotificationsPlugin>(
    FlutterLocalNotificationsPlugin(),
  );
  getIt.registerSingleton<WebSocketService>(WebSocketService());

  // ─── DEAD Dio kept alive to satisfy the generated injection.config.dart ─
  // The Clean-Architecture stack (AuthRepositoryImpl + AuthRemoteDataSource +
  // OrderRemoteDataSource against api.wintime.com) is NEVER CALLED in the
  // live app — login_page.dart talks to Supabase directly, and
  // SupabaseOrdersDataSource handles orders. But injection.config.dart still
  // references `gh<Dio>()` for the dead classes' constructors; removing the
  // Dio registration here would crash `getIt.init()` and produce a white
  // screen. The proper fix (T39) is to delete the dead source files and
  // re-run `dart run build_runner build --delete-conflicting-outputs` to
  // regenerate injection.config.dart without those bindings. Until then:
  if (!getIt.isRegistered<Dio>()) {
    getIt.registerSingleton<Dio>(
      Dio(
        BaseOptions(
          // Pointing at a deliberately-invalid host so anyone who finds this
          // Dio being USED at runtime gets a clear network error instead of
          // a confused timeout against a real-looking domain.
          baseUrl: 'https://dead-api.invalid/',
          connectTimeout: const Duration(seconds: 1),
          receiveTimeout: const Duration(seconds: 1),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ),
    );
  }

  // ─── FirebaseMessaging : optionnel ────────────────────────────────────
  // Si le plugin natif Firebase n'est pas configuré (GoogleService-Info.plist
  // absent), .instance peut throw ou hang. On tente, on log, on continue.
  try {
    getIt.registerSingleton<FirebaseMessaging>(FirebaseMessaging.instance);
  } catch (e) {
    debugPrint('⚠️ FirebaseMessaging not available: $e');
  }

  // ─── DI graph (généré par injectable) ─────────────────────────────────
  // Wrapping en try/catch : si une registration echoue (par ex. dépendance
  // Firebase manquante), l'app continue avec une init partielle.
  try {
    await getIt.init();
  } catch (e, st) {
    debugPrint('⚠️ getIt.init() failed (DI partielle) : $e\n$st');
  }
}
