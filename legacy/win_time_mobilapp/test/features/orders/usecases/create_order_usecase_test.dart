import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:win_time/core/errors/failures.dart';
import 'package:win_time/features/orders/domain/entities/order_entity.dart';
import 'package:win_time/features/orders/domain/repositories/order_repository.dart';
import 'package:win_time/features/orders/domain/usecases/create_order_usecase.dart';

// Mock du repository
class MockOrderRepository extends Mock implements OrderRepository {}

void main() {
  late CreateOrderUseCase useCase;
  late MockOrderRepository mockRepository;

  setUp(() {
    mockRepository = MockOrderRepository();
    useCase = CreateOrderUseCase(mockRepository);

    // Register fallback values pour mocktail
    registerFallbackValue(
      CreateOrderParams(
        restaurantId: '',
        items: [],
        totalAmount: 0,
        scheduledPickupTime: DateTime.now(),
        paymentMethodId: '',
      ),
    );
  });

  group('CreateOrderUseCase', () {
    final tRestaurantId = 'restaurant-123';
    final tItems = [
      OrderItemParams(
        productId: 'product-1',
        quantity: 2,
      ),
    ];
    final tTotalAmount = 25.50;
    final tScheduledPickupTime = DateTime.now().add(const Duration(minutes: 30));
    final tPaymentMethodId = 'pm_test_123';

    final tParams = CreateOrderParams(
      restaurantId: tRestaurantId,
      items: tItems,
      totalAmount: tTotalAmount,
      scheduledPickupTime: tScheduledPickupTime,
      paymentMethodId: tPaymentMethodId,
    );

    final tOrder = OrderEntity(
      id: 'order-123',
      orderNumber: '12345',
      customerId: 'customer-123',
      restaurantId: tRestaurantId,
      status: OrderStatus.pending,
      totalAmount: tTotalAmount,
      commissionAmount: 0.10,
      paymentStatus: PaymentStatus.paid,
      paymentMethod: 'card',
      estimatedPreparationTime: 20,
      scheduledPickupTime: tScheduledPickupTime,
      createdAt: DateTime.now(),
      items: const [],
    );

    test('should return OrderEntity when order creation succeeds', () async {
      // Arrange
      when(() => mockRepository.createOrder(any()))
          .thenAnswer((_) async => Right(tOrder));

      // Act
      final result = await useCase(tParams);

      // Assert
      expect(result, equals(Right(tOrder)));
      verify(() => mockRepository.createOrder(tParams)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return ValidationFailure when items list is empty', () async {
      // Arrange
      final emptyParams = CreateOrderParams(
        restaurantId: tRestaurantId,
        items: [], // Liste vide
        totalAmount: tTotalAmount,
        scheduledPickupTime: tScheduledPickupTime,
        paymentMethodId: tPaymentMethodId,
      );

      // Act
      final result = await useCase(emptyParams);

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            failure.message,
            'La commande doit contenir au moins un produit',
          );
        },
        (_) => fail('Should return ValidationFailure'),
      );
      verifyNever(() => mockRepository.createOrder(any()));
    });

    test('should return ValidationFailure when total amount is zero or negative',
        () async {
      // Arrange
      final invalidParams = CreateOrderParams(
        restaurantId: tRestaurantId,
        items: tItems,
        totalAmount: 0.0, // Montant invalide
        scheduledPickupTime: tScheduledPickupTime,
        paymentMethodId: tPaymentMethodId,
      );

      // Act
      final result = await useCase(invalidParams);

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            failure.message,
            'Le montant total doit être supérieur à 0',
          );
        },
        (_) => fail('Should return ValidationFailure'),
      );
      verifyNever(() => mockRepository.createOrder(any()));
    });

    test('should return ServerFailure when repository throws error', () async {
      // Arrange
      const tServerFailure = ServerFailure(
        message: 'Erreur serveur',
        statusCode: 500,
      );
      when(() => mockRepository.createOrder(any()))
          .thenAnswer((_) async => const Left(tServerFailure));

      // Act
      final result = await useCase(tParams);

      // Assert
      expect(result, equals(const Left(tServerFailure)));
      verify(() => mockRepository.createOrder(tParams)).called(1);
    });

    test('should return NetworkFailure when no internet connection', () async {
      // Arrange
      const tNetworkFailure = NetworkFailure();
      when(() => mockRepository.createOrder(any()))
          .thenAnswer((_) async => const Left(tNetworkFailure));

      // Act
      final result = await useCase(tParams);

      // Assert
      expect(result, equals(const Left(tNetworkFailure)));
      verify(() => mockRepository.createOrder(tParams)).called(1);
    });
  });
}
