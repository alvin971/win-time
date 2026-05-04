import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/supabase_orders_datasource.dart';

/// Liste des commandes du customer connecté, alimentée par un stream Supabase
/// realtime — donc se met à jour automatiquement quand le restaurant change
/// le statut.
class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});
  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  late final SupabaseOrdersDataSource _ds;
  late final Stream<List<OrderEntity>> _stream;

  @override
  void initState() {
    super.initState();
    _ds = SupabaseOrdersDataSource(Supabase.instance.client);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    _stream = uid != null ? _ds.watchMyOrders(uid) : const Stream.empty();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes commandes')),
      body: StreamBuilder<List<OrderEntity>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }
          final orders = snap.data ?? [];
          if (orders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Aucune commande pour le moment.'),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (_, i) => _OrderTile(order: orders[i]),
            ),
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderEntity order;
  const _OrderTile({required this.order});

  Color _statusColor() {
    switch (order.status) {
      case OrderStatus.pending:
        return Colors.amber;
      case OrderStatus.accepted:
      case OrderStatus.preparing:
        return Colors.blue;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.completed:
        return Colors.grey;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return Colors.red;
    }
  }

  String _statusLabel() {
    switch (order.status) {
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.accepted:
        return 'Acceptée';
      case OrderStatus.preparing:
        return 'En préparation';
      case OrderStatus.ready:
        return 'Prête à retirer';
      case OrderStatus.completed:
        return 'Terminée';
      case OrderStatus.cancelled:
        return 'Annulée';
      case OrderStatus.rejected:
        return 'Refusée';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => context.push('/orders/${order.id}'),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.receipt_long, color: color),
        ),
        title: Text(
          'Commande ${order.orderNumber}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${order.totalItems} article(s) — ${order.formattedTotal}'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusLabel(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
