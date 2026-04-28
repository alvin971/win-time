import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/order_model.dart';

abstract class OrdersRemoteDataSource {
  Future<List<OrderModel>> getActiveOrders({required String restaurantId});

  Future<List<OrderModel>> getOrderHistory({
    required String restaurantId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  });

  Future<OrderModel> getOrderById({required String orderId});

  Future<OrderModel> acceptOrder({
    required String orderId,
    int? estimatedPreparationTime,
  });

  Future<OrderModel> rejectOrder({
    required String orderId,
    required String reason,
  });

  Future<OrderModel> markOrderReady({required String orderId});

  Future<OrderModel> completeOrder({required String orderId});

  Future<void> updatePreparationTime({
    required String orderId,
    required int newTime,
  });
}

class OrdersRemoteDataSourceImpl implements OrdersRemoteDataSource {
  final DioClient _dioClient;

  OrdersRemoteDataSourceImpl(this._dioClient);

  @override
  Future<List<OrderModel>> getActiveOrders({required String restaurantId}) async {
    final response = await _dioClient.dio.get(
      '/restaurants/$restaurantId/orders/active',
    );
    final data = response.data as Map<String, dynamic>;
    final list = data['orders'] as List<dynamic>;
    return list
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<OrderModel>> getOrderHistory({
    required String restaurantId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    final response = await _dioClient.dio.get(
      '/restaurants/$restaurantId/orders/history',
      queryParameters: {
        if (startDate != null) 'start_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate.toIso8601String(),
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final list = data['orders'] as List<dynamic>;
    return list
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<OrderModel> getOrderById({required String orderId}) async {
    final response = await _dioClient.dio.get('/orders/$orderId');
    final data = response.data as Map<String, dynamic>;
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  @override
  Future<OrderModel> acceptOrder({
    required String orderId,
    int? estimatedPreparationTime,
  }) async {
    final response = await _dioClient.dio.post(
      '/orders/$orderId/accept',
      data: {
        if (estimatedPreparationTime != null)
          'estimated_preparation_time': estimatedPreparationTime,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  @override
  Future<OrderModel> rejectOrder({
    required String orderId,
    required String reason,
  }) async {
    final response = await _dioClient.dio.post(
      '/orders/$orderId/reject',
      data: {'reason': reason},
    );
    final data = response.data as Map<String, dynamic>;
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  @override
  Future<OrderModel> markOrderReady({required String orderId}) async {
    final response = await _dioClient.dio.post('/orders/$orderId/ready');
    final data = response.data as Map<String, dynamic>;
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  @override
  Future<OrderModel> completeOrder({required String orderId}) async {
    final response = await _dioClient.dio.post('/orders/$orderId/complete');
    final data = response.data as Map<String, dynamic>;
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  @override
  Future<void> updatePreparationTime({
    required String orderId,
    required int newTime,
  }) async {
    await _dioClient.dio.patch(
      '/orders/$orderId/preparation-time',
      data: {'estimated_preparation_time': newTime},
    );
  }
}
