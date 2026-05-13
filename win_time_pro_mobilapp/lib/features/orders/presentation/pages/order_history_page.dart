import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/order_model.dart';

/// Historique des commandes (terminées / annulées / rejetées) pour le
/// restaurant courant. La data-layer existait déjà
/// (`SupabaseOrdersDataSource.getOrderHistory`), il ne manquait que la page.
class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  static const int _pageSize = 30;

  List<OrderModel> _orders = const [];
  bool _loading = true;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _error;

  DateTime? _startDate;
  DateTime? _endDate;
  String _filter = 'all'; // all | completed | cancelled | rejected

  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _load(initial: true);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _load();
    }
  }

  Future<void> _load({bool initial = false}) async {
    final restId = ServiceLocator.currentRestaurantId;
    if (restId == null) {
      setState(() {
        _loading = false;
        _error = 'Aucun restaurant associé';
      });
      return;
    }
    setState(() {
      if (initial) {
        _loading = true;
        _orders = const [];
        _hasMore = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final batch = await ServiceLocator.ordersDataSource.getOrderHistory(
        restaurantId: restId,
        startDate: _startDate,
        endDate: _endDate,
        limit: _pageSize,
        offset: initial ? 0 : _orders.length,
      );
      final filtered = _filter == 'all'
          ? batch
          : batch.where((o) => o.status.name == _filter).toList();

      setState(() {
        _orders = [...(initial ? const <OrderModel>[] : _orders), ...filtered];
        _loading = false;
        _loadingMore = false;
        _hasMore = batch.length == _pageSize;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _load(initial: true);
    }
  }

  void _setFilter(String filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _load(initial: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des commandes'),
        actions: [
          IconButton(
            tooltip: 'Filtre date',
            icon: const Icon(Icons.date_range),
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterChips(current: _filter, onChanged: _setFilter),
          if (_startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Du ${DateFormat('d MMM y', 'fr_FR').format(_startDate!)} '
                      'au ${DateFormat('d MMM y', 'fr_FR').format(_endDate!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                      _load(initial: true);
                    },
                    child: const Text('Effacer'),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(_error!),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _load(initial: true),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    if (_orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text('Aucune commande sur cette période'),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(initial: true),
      child: ListView.separated(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _orders.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          if (i == _orders.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final o = _orders[i];
          return _OrderTile(order: o);
        },
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _FilterChips({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('all', 'Toutes'),
      ('completed', 'Terminées'),
      ('cancelled', 'Annulées'),
      ('rejected', 'Refusées'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(item.$2),
                selected: current == item.$1,
                onSelected: (_) => onChanged(item.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderModel order;
  const _OrderTile({required this.order});

  Color _statusColor() {
    switch (order.status.name) {
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return AppColors.warning;
      case 'rejected':
        return AppColors.error;
      default:
        return Colors.blueGrey;
    }
  }

  String _statusLabel() {
    switch (order.status.name) {
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      case 'rejected':
        return 'Refusée';
      default:
        return order.status.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM HH:mm', 'fr_FR');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: _statusColor().withOpacity(0.15),
        child: Icon(
          order.status.name == 'completed'
              ? Icons.check
              : order.status.name == 'rejected'
                  ? Icons.cancel
                  : Icons.do_not_disturb_on_outlined,
          color: _statusColor(),
        ),
      ),
      title: Text(
        '${order.orderNumber} · ${order.totalAmount.toStringAsFixed(2)} €',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${fmt.format(order.createdAt)} · ${order.items.length} article'
        '${order.items.length > 1 ? 's' : ''} · ${_statusLabel()}',
      ),
      // Once the OrderModel exposes invoice_number from migration 060,
      // surface it here next to the order number.
      trailing: const SizedBox.shrink(),
    );
  }
}
