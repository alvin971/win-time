import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/pages/splash_page.dart';
import '../../../menu/presentation/pages/menu_page.dart';
import '../../../profile/presentation/pages/my_restaurant_page.dart';
import '../../domain/entities/order_entity.dart' as domain;

// ---------------------------------------------------------------------------
// Modèles temporaires — seront remplacés par OrderEntity de shared_core
// une fois le data layer Orders implémenté
// ---------------------------------------------------------------------------

enum _OrderStatus { pending, inProgress, ready, completed }

class _Order {
  /// ID d'affichage (ex. "#123") — peut différer de [remoteId].
  final String id;

  /// UUID Postgres dans la table wintime.orders. Utilisé pour les UPDATEs.
  final String remoteId;
  final String customerName;
  final String tableNumber;
  final List<_OrderItem> items;
  final _OrderStatus status;
  final DateTime orderTime;
  final double total;

  const _Order({
    required this.id,
    required this.remoteId,
    required this.customerName,
    required this.tableNumber,
    required this.items,
    required this.status,
    required this.orderTime,
    required this.total,
  });
}

class _OrderItem {
  final String name;
  final int quantity;
  final double price;

  const _OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
  });
}

// ---------------------------------------------------------------------------
// Page principale du tableau de bord
// ---------------------------------------------------------------------------

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  StreamSubscription<List<dynamic>>? _ordersSub;
  String? _restaurantId;
  List<_Order> _orders = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// Récupère le restaurantId du commerçant connecté puis abonne le stream
  /// realtime des commandes actives sur ce resto. Le stream est alimenté par
  /// la Realtime publication Postgres (cf. migrations/20260504_010 — ALTER
  /// PUBLICATION supabase_realtime ADD TABLE wintime.orders).
  Future<void> _bootstrap() async {
    if (ServiceLocator.currentRestaurantId == null) {
      await ServiceLocator.resolveCurrentRestaurantId();
    }
    final rid = ServiceLocator.currentRestaurantId;
    if (!mounted) return;
    if (rid == null) {
      setState(() {
        _loading = false;
        _error = 'Aucun restaurant associé à ce compte.';
      });
      return;
    }
    setState(() {
      _restaurantId = rid;
      _loading = false;
    });
    _ordersSub = ServiceLocator.ordersDataSource
        .watchActiveOrders(rid)
        .listen((orders) {
      if (!mounted) return;
      setState(() {
        _orders = orders.map(_mapOrder).toList();
        _error = null;
      });
    }, onError: (Object e) {
      if (!mounted) return;
      setState(() => _error = 'Erreur stream commandes : $e');
    });
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    super.dispose();
  }

  /// Mappe un OrderEntity (Pro) vers le `_Order` local du dashboard.
  /// La table number n'a pas d'équivalent (commandes pickup) — on affiche
  /// le order_number à la place.
  _Order _mapOrder(dynamic order) {
    // `order` est un OrderModel (extends OrderEntity du domain Pro).
    final o = order as domain.OrderEntity;
    return _Order(
      id: '#${o.orderNumber}',
      customerName: o.customerInfo.name,
      tableNumber: 'Pickup',
      items: o.items
          .map((it) => _OrderItem(
                name: it.productName,
                quantity: it.quantity,
                price: it.unitPrice,
              ))
          .toList(),
      status: _statusFromDomain(o.status),
      orderTime: o.createdAt,
      total: o.totalAmount,
      remoteId: o.id,
    );
  }

  _OrderStatus _statusFromDomain(domain.OrderStatus s) {
    switch (s) {
      case domain.OrderStatus.pending:
        return _OrderStatus.pending;
      case domain.OrderStatus.accepted:
      case domain.OrderStatus.preparing:
        return _OrderStatus.inProgress;
      case domain.OrderStatus.ready:
        return _OrderStatus.ready;
      case domain.OrderStatus.completed:
      case domain.OrderStatus.cancelled:
      case domain.OrderStatus.rejected:
        return _OrderStatus.completed;
    }
  }

  List<_Order> _getByStatus(_OrderStatus status) =>
      _orders.where((o) => o.status == status).toList();

  /// Action utilisateur — déclenche un UPDATE Supabase sur la commande.
  /// Le stream realtime renverra la nouvelle valeur, donc pas de setState
  /// optimiste : la source de vérité reste Postgres.
  Future<void> _updateStatus(_Order order, _OrderStatus newStatus) async {
    final remote = ServiceLocator.ordersDataSource;
    try {
      switch (newStatus) {
        case _OrderStatus.inProgress:
          await remote.acceptOrder(orderId: order.remoteId);
          break;
        case _OrderStatus.ready:
          await remote.markOrderReady(orderId: order.remoteId);
          break;
        case _OrderStatus.completed:
          if (order.status == _OrderStatus.pending) {
            await remote.rejectOrder(
                orderId: order.remoteId, reason: 'Refusée par le restaurant');
          } else {
            await remote.completeOrder(orderId: order.remoteId);
          }
          break;
        case _OrderStatus.pending:
          // pas d'action retour vers pending
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    // CRITIQUE : passer par AuthRepository.logout() (pas juste Supabase.signOut)
    // car logout() appelle aussi _local.clearAll() pour vider le UserModel
    // caché en flutter_secure_storage. Sans ça, SplashPage relit le cache,
    // émet AuthAuthenticated, et ré-route immédiatement vers Dashboard
    // → boucle infinie où le user ne peut jamais revenir au login.
    await ServiceLocator.authRepository.logout();
    ServiceLocator.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SplashPage()),
      (_) => false,
    );
  }

  /// Pull-to-refresh / bouton refresh AppBar.
  /// Force un re-fetch one-shot via REST (le stream realtime continue
  /// d'écouter en parallèle).
  Future<void> _pullRefresh() async {
    final rid = _restaurantId;
    if (rid == null) {
      await _bootstrap();
      return;
    }
    try {
      final orders =
          await ServiceLocator.ordersDataSource.getActiveOrders(restaurantId: rid);
      if (!mounted) return;
      setState(() {
        _orders = orders.map(_mapOrder).toList();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refresh échoué : $e')),
      );
    }
  }

  Future<void> _openMyMenu() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const MenuPage()),
    );
  }

  Future<void> _openMyRestaurant({bool createMode = false}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MyRestaurantPage(
          restaurantId: createMode ? null : _restaurantId,
        ),
      ),
    );
    if (saved == true) {
      // Si on vient de créer le resto, recharger le restaurantId
      if (_restaurantId == null) {
        await ServiceLocator.resolveCurrentRestaurantId();
        if (mounted) {
          setState(() {
            _restaurantId = ServiceLocator.currentRestaurantId;
          });
          if (_restaurantId != null) {
            // Démarrer le stream maintenant qu'on a un resto
            await _bootstrap();
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_restaurantId == null) {
      final currentEmail = Supabase.instance.client.auth.currentUser?.email;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Win Time Pro'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Se déconnecter',
              onPressed: _signOut,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentEmail != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_circle,
                            size: 16, color: Colors.blueAccent),
                        const SizedBox(width: 6),
                        Text('Connecté: $currentEmail',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.blueAccent)),
                      ],
                    ),
                  ),
                const Icon(Icons.store_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Aucun restaurant associé à ce compte.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Crée ton restaurant pour commencer à recevoir des commandes en temps réel.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ℹ️ Aucun restaurant trouvé pour ce compte. '
                    'Tu peux en créer un nouveau ou te reconnecter avec '
                    'un autre compte démo (chaque rôle possède un resto seedé).',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _openMyRestaurant(createMode: true),
                  icon: const Icon(Icons.add_business),
                  label: const Text('Créer mon restaurant'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pending = _getByStatus(_OrderStatus.pending);
    final inProgress = _getByStatus(_OrderStatus.inProgress);
    final ready = _getByStatus(_OrderStatus.ready);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Quitter Win Time Pro ?'),
            content: const Text(
                'Tu vas fermer l\'application. Tu pourras la rouvrir à tout moment.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Quitter'),
              ),
            ],
          ),
        );
        if (shouldExit == true && mounted) {
          // Sortie propre : Navigator.maybePop n'est pas pertinent ici car on
          // est sur la page racine. On pop la stack au cas où il y aurait
          // un parent (auquel cas didPop aurait été true), sinon on laisse
          // l'OS gérer.
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Win Time Pro'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _pullRefresh,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'restaurant':
                  _openMyRestaurant();
                  break;
                case 'menu':
                  _openMyMenu();
                  break;
                case 'logout':
                  _signOut();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'restaurant',
                child: ListTile(
                  leading: Icon(Icons.storefront),
                  title: Text('Mon Restaurant'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'menu',
                child: ListTile(
                  leading: Icon(Icons.menu_book),
                  title: Text('Mon Menu'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Se déconnecter',
                      style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // KPI bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(child: _StatCard(title: 'À valider', count: pending.length, color: AppColors.warning, icon: Icons.pending_actions)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'En cours', count: inProgress.length, color: AppColors.info, icon: Icons.restaurant)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Prêtes', count: ready.length, color: AppColors.success, icon: Icons.check_circle)),
              ],
            ),
          ),
          // Onglets
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                _TabButton(title: 'À valider (${pending.length})', isSelected: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0)),
                _TabButton(title: 'En cours (${inProgress.length})', isSelected: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1)),
                _TabButton(title: 'Prêtes (${ready.length})', isSelected: _selectedIndex == 2, onTap: () => setState(() => _selectedIndex = 2)),
              ],
            ),
          ),
          // Liste avec pull-to-refresh
          Expanded(
            child: RefreshIndicator(
              onRefresh: _pullRefresh,
              child: _OrdersList(
                orders: [pending, inProgress, ready][_selectedIndex],
                onUpdateStatus: _updateStatus,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets internes
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const _StatCard({required this.title, required this.count, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(count.toString(), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({required this.title, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<_Order> orders;
  final void Function(_Order, _OrderStatus) onUpdateStatus;

  const _OrdersList({required this.orders, required this.onUpdateStatus});

  @override
  Widget build(BuildContext context) {
    // AlwaysScrollableScrollPhysics nécessaire pour que RefreshIndicator
    // s'active même quand la liste est vide.
    if (orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Aucune commande',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          )),
                  const SizedBox(height: 8),
                  Text('Tire vers le bas pour actualiser',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          )),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) => _OrderCard(order: orders[i], onUpdateStatus: onUpdateStatus),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final _Order order;
  final void Function(_Order, _OrderStatus) onUpdateStatus;

  const _OrderCard({required this.order, required this.onUpdateStatus});

  Color _statusColor() {
    switch (order.status) {
      case _OrderStatus.pending: return AppColors.warning;
      case _OrderStatus.inProgress: return AppColors.info;
      case _OrderStatus.ready: return AppColors.success;
      case _OrderStatus.completed: return Colors.grey;
    }
  }

  String _formatTime() {
    final diff = DateTime.now().difference(order.orderTime);
    return diff.inMinutes < 60 ? 'Il y a ${diff.inMinutes} min' : 'Il y a ${diff.inHours}h';
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(order.id, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.table_restaurant, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(order.tableNumber, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                  ],
                ),
                Text(_formatTime(), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: Center(child: Text('${item.quantity}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 12))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item.name, style: const TextStyle(fontSize: 14))),
                          ],
                        ),
                      ),
                      Text('${item.price.toStringAsFixed(2)}€', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    ],
                  ),
                )),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text('${order.total.toStringAsFixed(2)}€', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              ],
            ),
            const SizedBox(height: 16),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    switch (order.status) {
      case _OrderStatus.pending:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onUpdateStatus(order, _OrderStatus.completed),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Refuser'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: BorderSide(color: AppColors.error)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onUpdateStatus(order, _OrderStatus.inProgress),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Accepter'),
              ),
            ),
          ],
        );
      case _OrderStatus.inProgress:
        return ElevatedButton.icon(
          onPressed: () => onUpdateStatus(order, _OrderStatus.ready),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Marquer comme prête'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
        );
      case _OrderStatus.ready:
        return ElevatedButton.icon(
          onPressed: () => onUpdateStatus(order, _OrderStatus.completed),
          icon: const Icon(Icons.delivery_dining, size: 18),
          label: const Text('Servir'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size(double.infinity, 44)),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
