import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../theme/app_theme.dart';
import '../config/app_config.dart';

// ---------------------------------------------------------------------------
// Noms de routes (constantes — évite les typos dans le codebase)
// ---------------------------------------------------------------------------

abstract class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const restaurants = '/home/restaurants';
  static const orders = '/home/orders';
  static const profile = '/home/profile';
}

// ---------------------------------------------------------------------------
// Router principal
// ---------------------------------------------------------------------------

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: false,
  routes: [
    // Splash — vérifie l'état d'auth et redirige
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const _SplashPage(),
    ),

    // Auth
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => const RegisterPage(),
    ),

    // App principale — shell avec bottom navigation
    ShellRoute(
      builder: (context, state, child) => _HomeShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.restaurants,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: _RestaurantsTab(),
          ),
        ),
        GoRoute(
          path: AppRoutes.orders,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: _OrdersTab(),
          ),
        ),
        GoRoute(
          path: AppRoutes.profile,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: _ProfileTab(),
          ),
        ),
      ],
    ),

    // Redirection /home -> /home/restaurants
    GoRoute(
      path: AppRoutes.home,
      redirect: (_, __) => AppRoutes.restaurants,
    ),
  ],
);

// ---------------------------------------------------------------------------
// Splash page (logique d'auth à brancher sur AuthBloc quand implémenté)
// ---------------------------------------------------------------------------

class _SplashPage extends StatefulWidget {
  const _SplashPage();

  @override
  State<_SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<_SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      // TODO: brancher sur AuthBloc — si token valide -> /home, sinon -> /login
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            Text(
              AppConfig.appName.toUpperCase(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Click & Collect pour Restaurants',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shell avec bottom navigation
// ---------------------------------------------------------------------------

class _HomeShell extends StatelessWidget {
  final Widget child;

  const _HomeShell({required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.orders)) return 1;
    if (location.startsWith(AppRoutes.profile)) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex(context),
        onTap: (index) {
          switch (index) {
            case 0:
              context.go(AppRoutes.restaurants);
            case 1:
              context.go(AppRoutes.orders);
            case 2:
              context.go(AppRoutes.profile);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: 'Restaurants',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Commandes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tabs placeholder (seront remplacés par les vraies pages feature par feature)
// ---------------------------------------------------------------------------

class _RestaurantsTab extends StatelessWidget {
  const _RestaurantsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurants')),
      body: const Center(child: Text('Liste des restaurants à venir')),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes commandes')),
      body: const Center(child: Text('Liste des commandes à venir')),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: const Center(child: Text('Profil utilisateur à venir')),
    );
  }
}
