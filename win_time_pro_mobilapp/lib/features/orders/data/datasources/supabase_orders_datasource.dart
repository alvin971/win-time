import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/wintime_supabase_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/order_model.dart';
import 'orders_remote_datasource.dart';

/// Implémentation Supabase de [OrdersRemoteDataSource].
///
/// Lit/écrit la table `wintime.orders`. Le stream realtime est exposé via
/// [watchActiveOrders] (utilisé par le DashboardPage pour voir les nouvelles
/// commandes apparaître en live grâce à la Realtime publication Postgres).
class SupabaseOrdersDataSource implements OrdersRemoteDataSource {
  final SupabaseClient _client;

  SupabaseOrdersDataSource(this._client);

  /// Tables sont en schéma `wintime` — on récupère un PostgrestQueryBuilder
  /// préfixé pour garder le code lisible.
  PostgrestQueryBuilder get _orders =>
      _client.schema(WintimeSupabaseConfig.schema).from('orders');

  @override
  Future<List<OrderModel>> getActiveOrders({required String restaurantId}) async {
    try {
      final rows = await _orders
          .select()
          .eq('restaurant_id', restaurantId)
          .inFilter('status', const ['pending', 'accepted', 'preparing', 'ready'])
          .order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_modelFromRow)
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<List<OrderModel>> getOrderHistory({
    required String restaurantId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    try {
      var q = _orders
          .select()
          .eq('restaurant_id', restaurantId)
          .inFilter('status', const ['completed', 'cancelled', 'rejected']);
      if (startDate != null) {
        q = q.gte('created_at', startDate.toUtc().toIso8601String());
      }
      if (endDate != null) {
        q = q.lte('created_at', endDate.toUtc().toIso8601String());
      }
      var ordered = q.order('created_at', ascending: false);
      if (limit != null) ordered = ordered.limit(limit);
      if (offset != null) ordered = ordered.range(offset, offset + (limit ?? 50) - 1);
      final rows = await ordered;
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_modelFromRow)
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<OrderModel> getOrderById({required String orderId}) async {
    final row = await _orders.select().eq('id', orderId).single();
    return _modelFromRow(row);
  }

  @override
  Future<OrderModel> acceptOrder({
    required String orderId,
    int? estimatedPreparationTime,
  }) async {
    final updates = <String, dynamic>{
      'status': 'accepted',
      'accepted_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (estimatedPreparationTime != null) {
      updates['estimated_preparation_time'] = estimatedPreparationTime;
    }
    final row =
        await _orders.update(updates).eq('id', orderId).select().single();
    return _modelFromRow(row);
  }

  @override
  Future<OrderModel> rejectOrder({
    required String orderId,
    required String reason,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final row = await _orders
        .update({
          'status': 'rejected',
          'cancelled_at': now,
          'cancellation_reason': reason,
        })
        .eq('id', orderId)
        .select()
        .single();
    return _modelFromRow(row);
  }

  @override
  Future<OrderModel> markOrderReady({required String orderId}) async {
    final row = await _orders
        .update({
          'status': 'ready',
          'ready_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId)
        .select()
        .single();
    return _modelFromRow(row);
  }

  @override
  Future<OrderModel> completeOrder({required String orderId}) async {
    final row = await _orders
        .update({
          'status': 'completed',
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId)
        .select()
        .single();
    return _modelFromRow(row);
  }

  @override
  Future<void> updatePreparationTime({
    required String orderId,
    required int newTime,
  }) async {
    await _orders
        .update({'estimated_preparation_time': newTime})
        .eq('id', orderId);
  }

  /// Stream realtime des commandes actives d'un restaurant.
  ///
  /// IMPORTANT : on n'utilise PAS `.schema().from().stream()` car le `.stream()`
  /// du SDK supabase_flutter ignore le `.schema()` qui le précède (subscribe
  /// par défaut au schéma `public`). Comme nos tables sont dans `wintime`,
  /// on utilise l'API channel explicite `onPostgresChanges` avec le param
  /// `schema:` qui, lui, est respecté.
  ///
  /// Stratégie : initial fetch via REST (schema-aware) puis re-fetch sur
  /// chaque INSERT/UPDATE/DELETE détecté par le channel.
  Stream<List<OrderModel>> watchActiveOrders(String restaurantId) {
    final controller = StreamController<List<OrderModel>>();

    Future<void> refresh() async {
      try {
        final orders = await getActiveOrders(restaurantId: restaurantId);
        if (!controller.isClosed) controller.add(orders);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    // Premier fetch immédiat
    refresh();

    // Subscribe aux changements Postgres dans wintime.orders pour ce resto
    final channel = _client.channel(
      'pro-orders-$restaurantId-${DateTime.now().millisecondsSinceEpoch}',
    );
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: WintimeSupabaseConfig.schema,
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: restaurantId,
          ),
          callback: (_) => refresh(),
        )
        .subscribe();

    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };
    return controller.stream;
  }

  // ─── Helpers privés ──────────────────────────────────────────────────────

  /// Convertit une row Postgres (snake_case) vers un OrderModel (Pro).
  /// Le seul écart vs la version Dio originale : `created_at` côté Postgres
  /// devient `order_date` côté model Pro.
  OrderModel _modelFromRow(Map<String, dynamic> row) {
    final aliased = Map<String, dynamic>.from(row);
    aliased['order_date'] = row['created_at'];
    return OrderModel.fromJson(aliased);
  }
}
