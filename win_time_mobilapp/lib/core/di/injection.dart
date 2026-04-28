import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'injection.config.dart';
import '../services/websocket_service.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
Future<void> configureDependencies() async {
  // Dépendances platform enregistrées manuellement (non gérées par injectable)
  getIt.registerSingleton<FlutterLocalNotificationsPlugin>(
    FlutterLocalNotificationsPlugin(),
  );

  getIt.registerSingleton<WebSocketService>(WebSocketService());

  // Firebase : enregistré uniquement si disponible (google-services.json requis)
  try {
    getIt.registerSingleton<FirebaseMessaging>(FirebaseMessaging.instance);
  } catch (_) {
    // Firebase non configuré — notifications push désactivées
  }

  // Initialisation injectable : enregistre ApiClient (@singleton), datasources, repositories
  await getIt.init();
}
