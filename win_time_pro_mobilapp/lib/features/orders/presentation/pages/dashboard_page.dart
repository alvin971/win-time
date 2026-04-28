import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Modèles temporaires — seront remplacés par OrderEntity de shared_core
// une fois le data layer Orders implémenté
// ---------------------------------------------------------------------------

enum _OrderStatus { pending, inProgress, ready, completed }

class _Order {
  final String id;
  final String customerName;
  final String tableNumber;
  final List<_OrderItem> items;
  final _OrderStatus status;
  final DateTime orderTime;
  final double total;

  const _Order({
    required this.id,
    required this.customerName,
    required this.tableNumber,
    required this.items,
    required this.status,
    required this.orderTime,
    required this.total,
  });

  _Order copyWith({_OrderStatus? status}) => _Order(
        id: id,
        customerName: customerName,
        tableNumber: tableNumber,
        items: items,
        status: status ?? this.status,
        orderTime: orderTime,
        total: total,
      );
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

  // Données de démo — seront remplacées par OrdersBloc quand le data layer sera prêt
  late List<_Order> _orders;

  @override
  void initState() {
    super.initState();
    _orders = _buildDemoOrders();
  }

  List<_Order> _buildDemoOrders() => [
        _Order(
          id: '#001',
          customerName: 'Jean Dupont',
          tableNumber: 'Table 5',
          items: const [
            _OrderItem(name: 'Pizza Margherita', quantity: 2, price: 12.50),
            _OrderItem(name: 'Salade César', quantity: 1, price: 8.00),
            _OrderItem(name: 'Coca-Cola', quantity: 2, price: 3.50),
          ],
          status: _OrderStatus.pending,
          orderTime: DateTime.now().subtract(const Duration(minutes: 2)),
          total: 40.00,
        ),
        _Order(
          id: '#002',
          customerName: 'Marie Martin',
          tableNumber: 'Table 3',
          items: const [
            _OrderItem(name: 'Burger Bacon', quantity: 1, price: 15.00),
            _OrderItem(name: 'Frites', quantity: 1, price: 4.50),
            _OrderItem(name: 'Milkshake Vanille', quantity: 1, price: 5.00),
          ],
          status: _OrderStatus.pending,
          orderTime: DateTime.now().subtract(const Duration(minutes: 5)),
          total: 24.50,
        ),
        _Order(
          id: '#003',
          customerName: 'Pierre Durand',
          tableNumber: 'Table 8',
          items: const [
            _OrderItem(name: 'Pâtes Carbonara', quantity: 1, price: 14.00),
            _OrderItem(name: 'Tiramisu', quantity: 1, price: 6.50),
          ],
          status: _OrderStatus.inProgress,
          orderTime: DateTime.now().subtract(const Duration(minutes: 15)),
          total: 20.50,
        ),
        _Order(
          id: '#004',
          customerName: 'Sophie Bernard',
          tableNumber: 'Table 2',
          items: const [
            _OrderItem(name: 'Steak Frites', quantity: 2, price: 18.00),
            _OrderItem(name: 'Vin Rouge (verre)', quantity: 2, price: 6.00),
          ],
          status: _OrderStatus.inProgress,
          orderTime: DateTime.now().subtract(const Duration(minutes: 20)),
          total: 48.00,
        ),
        _Order(
          id: '#005',
          customerName: 'Luc Petit',
          tableNumber: 'Table 1',
          items: const [
            _OrderItem(name: 'Sushi Mix', quantity: 1, price: 22.00),
            _OrderItem(name: 'Soupe Miso', quantity: 1, price: 4.50),
          ],
          status: _OrderStatus.ready,
          orderTime: DateTime.now().subtract(const Duration(minutes: 25)),
          total: 26.50,
        ),
      ];

  List<_Order> _getByStatus(_OrderStatus status) =>
      _orders.where((o) => o.status == status).toList();

  void _updateStatus(_Order order, _OrderStatus newStatus) {
    setState(() {
      final idx = _orders.indexWhere((o) => o.id == order.id);
      if (idx != -1) _orders[idx] = order.copyWith(status: newStatus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = _getByStatus(_OrderStatus.pending);
    final inProgress = _getByStatus(_OrderStatus.inProgress);
    final ready = _getByStatus(_OrderStatus.ready);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Win Time Pro'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
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
          // Liste
          Expanded(child: _OrdersList(
            orders: [pending, inProgress, ready][_selectedIndex],
            onUpdateStatus: _updateStatus,
          )),
        ],
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
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Aucune commande', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
          ],
        ),
      );
    }
    return ListView.builder(
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
