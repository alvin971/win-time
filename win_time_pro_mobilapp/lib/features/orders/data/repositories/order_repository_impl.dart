import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/websocket_service.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/orders_remote_datasource.dart';
import '../models/order_model.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrdersRemoteDataSource _remote;
  final WebSocketService _wsService;

  OrderRepositoryImpl({
    required OrdersRemoteDataSource remote,
    required WebSocketService wsService,
  })  : _remote = remote,
        _wsService = wsService;

  @override
  Future<Either<Failure, List<OrderEntity>>> getActiveOrders({
    required String restaurantId,
  }) async {
    try {
      final orders = await _remote.getActiveOrders(restaurantId: restaurantId);
      return Right(orders);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getOrderHistory({
    required String restaurantId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    try {
      final orders = await _remote.getOrderHistory(
        restaurantId: restaurantId,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
        offset: offset,
      );
      return Right(orders);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> getOrderById({
    required String orderId,
  }) async {
    try {
      final order = await _remote.getOrderById(orderId: orderId);
      return Right(order);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> acceptOrder({
    required String orderId,
    int? estimatedPreparationTime,
  }) async {
    try {
      final order = await _remote.acceptOrder(
        orderId: orderId,
        estimatedPreparationTime: estimatedPreparationTime,
      );
      return Right(order);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> rejectOrder({
    required String orderId,
    required String reason,
  }) async {
    try {
      final order = await _remote.rejectOrder(orderId: orderId, reason: reason);
      return Right(order);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> markOrderReady({
    required String orderId,
  }) async {
    try {
      final order = await _remote.markOrderReady(orderId: orderId);
      return Right(order);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> completeOrder({
    required String orderId,
  }) async {
    try {
      final order = await _remote.completeOrder(orderId: orderId);
      return Right(order);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> updatePreparationTime({
    required String orderId,
    required int newTime,
  }) async {
    try {
      await _remote.updatePreparationTime(orderId: orderId, newTime: newTime);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  // ---------------------------------------------------------------------------
  // Streams WebSocket — émis par le serveur en temps réel
  // ---------------------------------------------------------------------------

  @override
  Stream<OrderEntity> watchNewOrders({required String restaurantId}) {
    return _wsService.newOrders
        .where((data) => data['restaurant_id'] == restaurantId)
        .map((data) => OrderModel.fromJson(data));
  }

  @override
  Stream<List<OrderEntity>> watchActiveOrders({required String restaurantId}) {
    // Émet une liste mise à jour à chaque changement de statut d'une commande active
    return _wsService.orderUpdates
        .where((data) => data['restaurant_id'] == restaurantId)
        .asyncMap((_) async {
      final result = await getActiveOrders(restaurantId: restaurantId);
      return result.fold(
        (_) => <OrderEntity>[],
        (orders) => orders,
      );
    });
  }
}
