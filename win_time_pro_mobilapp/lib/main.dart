import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/splash_page.dart';

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

    // Init avec timeout ET try/catch : si un service natif (Firebase,
    // secure_storage, etc.) hang ou throw, on continue malgré tout pour
    // que runApp() soit appelé. Sans ça, écran blanc permanent en TestFlight.
    try {
      await ServiceLocator.init().timeout(const Duration(seconds: 15));
    } catch (e, st) {
      debugPrint('⚠️ ServiceLocator.init failed/timed-out: $e\n$st');
    }

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    runApp(const WinTimeProApp());
  }, (error, stack) {
    debugPrint('Async error caught by runZonedGuarded: $error\n$stack');
  });
}

class WinTimeProApp extends StatelessWidget {
  const WinTimeProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // TODO: remplacer AuthRepositoryImpl() par l'injection GetIt quand le data layer est prêt
        // BlocProvider(create: (_) => AuthBloc(authRepository: getIt<AuthRepository>())),
        BlocProvider(
          create: (_) => AuthBloc(
            authRepository: ServiceLocator.authRepository,
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'FR'),
          Locale('en', 'US'),
        ],
        locale: const Locale('fr', 'FR'),
        home: const SplashPage(),
      ),
    );
  }
}
