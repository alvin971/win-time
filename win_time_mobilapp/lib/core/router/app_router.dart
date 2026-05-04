import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/checkout/presentation/pages/checkout_page.dart';
import '../../features/orders/presentation/pages/my_orders_page.dart';
import '../../features/orders/presentation/pages/order_tracking_page.dart';
import '../../features/restaurants/presentation/pages/restaurant_detail_page.dart';
import '../../features/restaurants/presentation/pages/restaurants_list_page.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';

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
  static const checkout = '/checkout';

  /// Page tracking d'une commande spécifique : /orders/:id
  static String orderTracking(String id) => '/orders/$id';

  /// Page détail d'un restaurant : /home/restaurants/:id
  static String restaurantDetail(String id) => '/home/restaurants/$id';
}

// ---------------------------------------------------------------------------
// Router principal
// ---------------------------------------------------------------------------

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: false,

  // Redirige vers login si non connecté (sauf splash/login/register).
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final goingToAuth = state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.register ||
        state.matchedLocation == AppRoutes.splash;
    if (!isLoggedIn && !goingToAuth) return AppRoutes.login;
    return null;
  },

  // Notifie le router quand l'auth change (login/logout) pour re-évaluer la
  // redirection automatiquement.
  refreshListenable: _AuthRefreshNotifier(),

  routes: [
    // Splash — résout l'état d'auth puis redirige
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const _SplashPage(),
    ),

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
            child: RestaurantsListPage(),
          ),
          routes: [
            // Détail resto en sous-route → navigation push avec back arrow
            GoRoute(
              path: ':restaurantId',
              builder: (context, state) {
                final id = state.pathParameters['restaurantId']!;
                return RestaurantDetailPage(restaurantId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.orders,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MyOrdersPage(),
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

    // Routes sans shell (full screen)
    GoRoute(
      path: AppRoutes.checkout,
      builder: (context, state) => const CheckoutPage(),
    ),
    GoRoute(
      path: '/orders/:orderId',
      builder: (context, state) {
        final id = state.pathParameters['orderId']!;
        return OrderTrackingPage(orderId: id);
      },
    ),

    // Redirection /home -> /home/restaurants
    GoRoute(
      path: AppRoutes.home,
      redirect: (_, __) => AppRoutes.restaurants,
    ),
  ],
);

// ---------------------------------------------------------------------------
// Auth refresh notifier — go_router se rafraîchit quand l'auth state change
// ---------------------------------------------------------------------------

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

// ---------------------------------------------------------------------------
// Splash page (auth-aware)
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeNext());
  }

  void _routeNext() {
    final user = Supabase.instance.client.auth.currentUser;
    if (!mounted) return;
    if (user != null) {
      context.go(AppRoutes.restaurants);
    } else {
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
// Profile tab — minimal pour ce checkpoint (email + sign out).
// ---------------------------------------------------------------------------

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person, size: 40, color: Colors.orange),
              title: Text(user?.email ?? 'Non connecté'),
              subtitle: Text(user?.id ?? '—',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
