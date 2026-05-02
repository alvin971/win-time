import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../config/app_config.dart';
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

  // ─── Dio : pré-enregistré pour OrderRemoteDataSource ──────────────────
  // injection.config.dart (régénéré par build_runner au CI) attend
  // `gh<Dio>()` pour construire OrderRemoteDataSourceImpl. Sans ça,
  // getIt.init() throw `Object/factory of type Dio is not registered`
  // et l'exception remonte jusqu'à main() → écran blanc en TestFlight.
  if (!getIt.isRegistered<Dio>()) {
    getIt.registerSingleton<Dio>(
      Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: AppConfig.connectionTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
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
