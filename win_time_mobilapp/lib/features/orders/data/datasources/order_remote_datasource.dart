import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../models/order_model.dart';

abstract class OrderRemoteDataSource {
  Future<OrderModel> createOrder(Map<String, dynamic> orderData);
  Future<List<OrderModel>> getMyOrders({int page, int pageSize});
  Future<OrderModel> getOrderById(String orderId);
  Future<OrderModel> cancelOrder(String orderId);
  Future<OrderModel> updateOrderStatus(String orderId, Map<String, dynamic> statusData);
  Future<OrderModel> markOrderAsReady(String orderId);
}

@Singleton(as: OrderRemoteDataSource)
class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  OrderRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<OrderModel> createOrder(Map<String, dynamic> orderData) async {
    final response = await _dio.post<Map<String, dynamic>>('/orders', data: orderData);
    return OrderModel.fromJson(response.data!);
  }

  @override
  Future<List<OrderModel>> getMyOrders({int page = 1, int pageSize = 20}) async {
    final response = await _dio.get<List<dynamic>>(
      '/orders/me',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    return (response.data as List).map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<OrderModel> getOrderById(String orderId) async {
    final response = await _dio.get<Map<String, dynamic>>('/orders/$orderId');
    return OrderModel.fromJson(response.data!);
  }

  @override
  Future<OrderModel> cancelOrder(String orderId) async {
    final response = await _dio.patch<Map<String, dynamic>>('/orders/$orderId/cancel');
    return OrderModel.fromJson(response.data!);
  }

  @override
  Future<OrderModel> updateOrderStatus(String orderId, Map<String, dynamic> statusData) async {
    final response = await _dio.patch<Map<String, dynamic>>('/orders/$orderId/status', data: statusData);
    return OrderModel.fromJson(response.data!);
  }

  @override
  Future<OrderModel> markOrderAsReady(String orderId) async {
    final response = await _dio.patch<Map<String, dynamic>>('/orders/$orderId/mark-ready');
    return OrderModel.fromJson(response.data!);
  }
}
