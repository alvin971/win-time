import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/order_entity.dart';

abstract class OrderRepository {
  Future<Either<Failure, List<OrderEntity>>> getActiveOrders({
    required String restaurantId,
  });

  Future<Either<Failure, List<OrderEntity>>> getOrderHistory({
    required String restaurantId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  });

  Future<Either<Failure, OrderEntity>> getOrderById({
    required String orderId,
  });

  Future<Either<Failure, OrderEntity>> acceptOrder({
    required String orderId,
    int? estimatedPreparationTime,
  });

  Future<Either<Failure, OrderEntity>> rejectOrder({
    required String orderId,
    required String reason,
  });

  Future<Either<Failure, OrderEntity>> markOrderReady({
    required String orderId,
  });

  Future<Either<Failure, OrderEntity>> completeOrder({
    required String orderId,
  });

  Future<Either<Failure, void>> updatePreparationTime({
    required String orderId,
    required int newTime,
  });

  Stream<OrderEntity> watchNewOrders({required String restaurantId});

  Stream<List<OrderEntity>> watchActiveOrders({required String restaurantId});
}
