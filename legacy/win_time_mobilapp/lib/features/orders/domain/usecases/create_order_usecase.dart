import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/order_entity.dart';
import '../repositories/order_repository.dart';

@injectable
class CreateOrderUseCase implements UseCase<OrderEntity, CreateOrderParams> {
  final OrderRepository repository;

  CreateOrderUseCase(this.repository);

  @override
  Future<Either<Failure, OrderEntity>> call(CreateOrderParams params) async {
    // Validation métier
    if (params.items.isEmpty) {
      return const Left(
        ValidationFailure(message: 'La commande doit contenir au moins un produit'),
      );
    }

    if (params.totalAmount <= 0) {
      return const Left(
        ValidationFailure(message: 'Le montant total doit être supérieur à 0'),
      );
    }

    return await repository.createOrder(params);
  }
}

class CreateOrderParams {
  final String restaurantId;
  final List<OrderItemParams> items;
  final double totalAmount;
  final DateTime scheduledPickupTime;
  final String? specialInstructions;
  final String paymentMethodId;

  CreateOrderParams({
    required this.restaurantId,
    required this.items,
    required this.totalAmount,
    required this.scheduledPickupTime,
    this.specialInstructions,
    required this.paymentMethodId,
  });
}

class OrderItemParams {
  final String productId;
  final int quantity;
  final Map<String, dynamic>? optionsSelected;
  final String? specialNotes;

  OrderItemParams({
    required this.productId,
    required this.quantity,
    this.optionsSelected,
    this.specialNotes,
  });
}
