import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dio/dio.dart';
import '../models/order_model.dart';

part 'order_remote_datasource.g.dart';

@singleton
@RestApi()
abstract class OrderRemoteDataSource {
  @factoryMethod
  factory OrderRemoteDataSource(Dio dio) = _OrderRemoteDataSource;

  @POST('/orders')
  Future<OrderModel> createOrder(@Body() Map<String, dynamic> orderData);

  @GET('/orders/me')
  Future<List<OrderModel>> getMyOrders({
    @Query('page') int page = 1,
    @Query('page_size') int pageSize = 20,
  });

  @GET('/orders/{id}')
  Future<OrderModel> getOrderById(@Path('id') String orderId);

  @PATCH('/orders/{id}/cancel')
  Future<OrderModel> cancelOrder(@Path('id') String orderId);

  @PATCH('/orders/{id}/status')
  Future<OrderModel> updateOrderStatus(
    @Path('id') String orderId,
    @Body() Map<String, dynamic> statusData,
  );

  @PATCH('/orders/{id}/mark-ready')
  Future<OrderModel> markOrderAsReady(@Path('id') String orderId);
}
