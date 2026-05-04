import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'core/config/wintime_supabase_config.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/cart/presentation/bloc/cart_bloc.dart';

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

    // Si un build de widget throw, on l'affiche visiblement (au lieu du
    // widget gris par défaut en release mode → indistinguable d'un blanc).
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Erreur de démarrage :\n\n${details.exception}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    };

    // Supabase : init OBLIGATOIRE avant configureDependencies (datasources
    // restaurants/menu/orders en dépendent). En cas de fail, l'app affichera
    // une erreur sur le login plutôt qu'un écran blanc.
    try {
      await Supabase.initialize(
        url: WintimeSupabaseConfig.url,
        anonKey: WintimeSupabaseConfig.anonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        debug: kDebugMode,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('⚠️ Supabase.initialize failed/timed-out: $e');
    }

    // Firebase : optionnel (FCM uniquement)
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
    return BlocProvider(
      create: (_) => CartBloc(),
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        routerConfig: appRouter,
      ),
    );
  }
}
