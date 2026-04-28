import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/usecases/create_order_usecase.dart';
import '../datasources/order_remote_datasource.dart';

@LazySingleton(as: OrderRepository)
class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource remoteDataSource;

  OrderRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, OrderEntity>> createOrder(
    CreateOrderParams params,
  ) async {
    try {
      final orderData = {
        'restaurant_id': params.restaurantId,
        'items': params.items
            .map((item) => {
                  'product_id': item.productId,
                  'quantity': item.quantity,
                  'options_selected': item.optionsSelected,
                  'special_notes': item.specialNotes,
                })
            .toList(),
        'total_amount': params.totalAmount,
        'scheduled_pickup_time': params.scheduledPickupTime.toIso8601String(),
        'special_instructions': params.specialInstructions,
        'payment_method_id': params.paymentMethodId,
      };

      final orderModel = await remoteDataSource.createOrder(orderData);
      return Right(orderModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Une erreur inattendue s\'est produite'));
    }
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getMyOrders({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final ordersModel = await remoteDataSource.getMyOrders(
        page: page,
        pageSize: pageSize,
      );
      final orders = ordersModel.map((model) => model.toEntity()).toList();
      return Right(orders);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Erreur lors de la récupération des commandes'));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> getOrderById(String orderId) async {
    try {
      final orderModel = await remoteDataSource.getOrderById(orderId);
      return Right(orderModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Erreur lors de la récupération de la commande'));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> cancelOrder(String orderId) async {
    try {
      final orderModel = await remoteDataSource.cancelOrder(orderId);
      return Right(orderModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Erreur lors de l\'annulation de la commande'));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
  }) async {
    try {
      final statusData = {'status': newStatus.toString().split('.').last};
      final orderModel = await remoteDataSource.updateOrderStatus(
        orderId,
        statusData,
      );
      return Right(orderModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Erreur lors de la mise à jour du statut'));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> markOrderAsReady(String orderId) async {
    try {
      final orderModel = await remoteDataSource.markOrderAsReady(orderId);
      return Right(orderModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Erreur lors du marquage de la commande'));
    }
  }

  @override
  Stream<OrderEntity> watchOrder(String orderId) {
    // TODO: Implémenter WebSocket ou polling pour le suivi en temps réel
    throw UnimplementedError('WebSocket support à implémenter');
  }
}
