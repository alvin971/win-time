import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/order_entity.dart';
import '../usecases/create_order_usecase.dart';

/// Contrat abstrait pour le repository des commandes
abstract class OrderRepository {
  Future<Either<Failure, OrderEntity>> createOrder(CreateOrderParams params);

  Future<Either<Failure, List<OrderEntity>>> getMyOrders({
    int page = 1,
    int pageSize = 20,
  });

  Future<Either<Failure, OrderEntity>> getOrderById(String orderId);

  Future<Either<Failure, OrderEntity>> cancelOrder(String orderId);

  Future<Either<Failure, OrderEntity>> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
  });

  Future<Either<Failure, OrderEntity>> markOrderAsReady(String orderId);

  Stream<OrderEntity> watchOrder(String orderId);
}
