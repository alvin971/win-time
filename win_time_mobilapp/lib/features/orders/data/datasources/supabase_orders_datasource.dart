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
  Stream<OrderEntity?> watchOrderById(String orderId) {
    return _client
        .schema(WintimeSupabaseConfig.schema)
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((rows) => rows.isEmpty
            ? null
            : OrderModel.fromRow(rows.first));
  }

  /// Stream des commandes du customer connecté, ordre date desc.
  Stream<List<OrderEntity>> watchMyOrders(String customerId) {
    return _client
        .schema(WintimeSupabaseConfig.schema)
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(OrderModel.fromRow).toList());
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
