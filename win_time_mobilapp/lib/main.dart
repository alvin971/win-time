import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/config/app_config.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  // Garde-fou anti-écran-blanc : tout crash async non capturé est loggé
  // au lieu de produire un écran blanc silencieux indistingable d'un hang.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint(
        'FlutterError: ${details.exception}\n${details.stack}',
      );
    };

    // Firebase : optionnel (GoogleService-Info.plist absent en TestFlight pour le moment)
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('⚠️ Firebase.initializeApp failed/timed-out: $e');
    }

    // Hive : doit toujours réussir mais on guarde au cas où
    try {
      await Hive.initFlutter();
    } catch (e) {
      debugPrint('⚠️ Hive.initFlutter failed: $e');
    }

    // DI : maintenant tolérante à Firebase absent + Dio pré-enregistré
    try {
      await configureDependencies().timeout(const Duration(seconds: 15));
    } catch (e, st) {
      debugPrint('⚠️ configureDependencies failed/timed-out: $e\n$st');
    }

    runApp(const WinTimeApp());
  }, (error, stack) {
    debugPrint('Async error caught by runZonedGuarded: $error\n$stack');
  });
}

class WinTimeApp extends StatelessWidget {
  const WinTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
