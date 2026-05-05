import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/cart/presentation/bloc/cart_bloc.dart';
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
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, cart) {
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
            items: [
              BottomNavigationBarItem(
                icon: cart.itemCount > 0
                    ? _BadgeIcon(
                        icon: const Icon(Icons.restaurant),
                        count: cart.itemCount,
                      )
                    : const Icon(Icons.restaurant),
                label: 'Restaurants',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.shopping_bag),
                label: 'Commandes',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profil',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final Icon icon;
  final int count;
  const _BadgeIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -8,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              count > 9 ? '9+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Profile tab — éditable (nom, téléphone, email read-only) + sign out.
// ---------------------------------------------------------------------------

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final row = await Supabase.instance.client
          .schema('wintime')
          .from('user_profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      _firstNameCtrl.text = (row?['first_name'] as String?) ?? '';
      _lastNameCtrl.text = (row?['last_name'] as String?) ?? '';
      _phoneCtrl.text = (row?['phone_number'] as String?) ?? '';
      setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client
          .schema('wintime')
          .from('user_profiles')
          .update({
            'first_name': _firstNameCtrl.text.trim(),
            'last_name': _lastNameCtrl.text.trim(),
            'phone_number': _phoneCtrl.text.trim().isEmpty
                ? null
                : _phoneCtrl.text.trim(),
          })
          .eq('id', uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour')),
      );
      setState(() => _dirty = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Form(
        key: _formKey,
        onChanged: () => setState(() => _dirty = true),
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person, size: 40, color: Colors.orange),
              title: Text(user?.email ?? 'Non connecté'),
              subtitle: const Text('Email non modifiable',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _firstNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Prénom',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lastNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nom',
              prefixIcon: Icon(Icons.badge),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone (optionnel)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: (_saving || !_dirty) ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: const Text('Enregistrer'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
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
      ),
    );
  }
}
