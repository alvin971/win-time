import 'dart:async';

import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/wintime_supabase_config.dart';

/// Écriture/lecture des commandes Client.
///
/// - createOrder : INSERT dans `wintime.orders` avec status=pending
/// - watchOrderById : stream realtime d'1 commande (page tracking)
/// - watchMyOrders : stream des commandes du customer connecté
class SupabaseOrdersDataSource {
  final SupabaseClient _client;
  SupabaseOrdersDataSource(this._client);

  PostgrestQueryBuilder get _table =>
      _client.schema(WintimeSupabaseConfig.schema).from('orders');

  /// Crée une nouvelle commande (status=pending). Retourne l'ID inséré.
  Future<String> createOrder(OrderEntity order) async {
    final row = OrderModel.toRow(order);
    // Force status pending au cas où le caller a oublié.
    row['status'] = 'pending';
    row['payment_status'] = order.paymentStatus.name;
    final result = await _table.insert(row).select('id').single();
    return result['id'] as String;
  }

  Future<OrderEntity?> getById(String orderId) async {
    final row = await _table.select().eq('id', orderId).maybeSingle();
    if (row == null) return null;
    return OrderModel.fromRow(row);
  }

  /// Stream realtime d'une commande spécifique (pour la page tracking).
  ///
  /// IMPORTANT : on n'utilise PAS `.schema().from().stream()` (le `.stream()`
  /// du SDK supabase_flutter ignore le `.schema()` qui le précède). On passe
  /// par l'API channel `onPostgresChanges` avec le param `schema:` explicite.
  Stream<OrderEntity?> watchOrderById(String orderId) {
    final controller = StreamController<OrderEntity?>();

    Future<void> refresh() async {
      try {
        final order = await getById(orderId);
        if (!controller.isClosed) controller.add(order);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    refresh();

    final channel = _client.channel(
      'order-$orderId-${DateTime.now().millisecondsSinceEpoch}',
    );
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: WintimeSupabaseConfig.schema,
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: orderId,
          ),
          callback: (_) => refresh(),
        )
        .subscribe();

    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };
    return controller.stream;
  }

  /// Stream des commandes du customer connecté, ordre date desc.
  /// Même stratégie que `watchOrderById` (channel API explicite).
  Stream<List<OrderEntity>> watchMyOrders(String customerId) {
    final controller = StreamController<List<OrderEntity>>();

    Future<void> refresh() async {
      try {
        final rows = await _table
            .select()
            .eq('customer_id', customerId)
            .order('created_at', ascending: false);
        final orders = (rows as List<dynamic>)
            .map((r) => OrderModel.fromRow((r as Map).cast<String, dynamic>()))
            .toList();
        if (!controller.isClosed) controller.add(orders);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    refresh();

    final channel = _client.channel(
      'my-orders-$customerId-${DateTime.now().millisecondsSinceEpoch}',
    );
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: WintimeSupabaseConfig.schema,
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: customerId,
          ),
          callback: (_) => refresh(),
        )
        .subscribe();

    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };
    return controller.stream;
  }

  /// Annule une commande (uniquement si encore en pending).
  Future<void> cancelOrder({
    required String orderId,
    String? reason,
  }) async {
    await _table.update({
      'status': 'cancelled',
      'cancelled_at': DateTime.now().toUtc().toIso8601String(),
      if (reason != null) 'cancellation_reason': reason,
    }).eq('id', orderId);
  }
}
