import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:win_time/core/errors/failures.dart';
import 'package:win_time/features/orders/domain/entities/order_entity.dart';
import 'package:win_time/features/orders/domain/repositories/order_repository.dart';
import 'package:win_time/features/orders/domain/usecases/create_order_usecase.dart';
import 'package:win_time/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:win_time/features/orders/presentation/bloc/orders_event.dart';
import 'package:win_time/features/orders/presentation/bloc/orders_state.dart';

class MockOrderRepository extends Mock implements OrderRepository {}

class MockCreateOrderUseCase extends Mock implements CreateOrderUseCase {}

void main() {
  late OrdersBloc bloc;
  late MockOrderRepository mockRepository;
  late MockCreateOrderUseCase mockCreateOrderUseCase;

  setUp(() {
    mockRepository = MockOrderRepository();
    mockCreateOrderUseCase = MockCreateOrderUseCase();
    bloc = OrdersBloc(
      orderRepository: mockRepository,
      createOrderUseCase: mockCreateOrderUseCase,
    );

    // Register fallback values
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

  tearDown(() {
    bloc.close();
  });

  group('OrdersBloc', () {
    final tOrders = [
      OrderEntity(
        id: 'order-1',
        orderNumber: '12345',
        customerId: 'customer-1',
        restaurantId: 'restaurant-1',
        status: OrderStatus.pending,
        totalAmount: 25.50,
        commissionAmount: 0.10,
        paymentStatus: PaymentStatus.paid,
        paymentMethod: 'card',
        estimatedPreparationTime: 20,
        scheduledPickupTime: DateTime.now().add(const Duration(minutes: 30)),
        createdAt: DateTime.now(),
        items: const [],
      ),
    ];

    test('initial state should be OrdersInitial', () {
      // Assert
      expect(bloc.state, equals(OrdersInitial()));
    });

    group('LoadMyOrders', () {
      blocTest<OrdersBloc, OrdersState>(
        'emits [OrdersLoading, OrdersLoaded] when loading orders succeeds',
        build: () {
          when(() => mockRepository.getMyOrders(page: any(named: 'page')))
              .thenAnswer((_) async => Right(tOrders));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadMyOrders()),
        expect: () => [
          OrdersLoading(),
          OrdersLoaded(
            orders: tOrders,
            hasMorePages: false,
            currentPage: 1,
          ),
        ],
        verify: (_) {
          verify(() => mockRepository.getMyOrders(page: 1)).called(1);
        },
      );

      blocTest<OrdersBloc, OrdersState>(
        'emits [OrdersLoading, OrdersError] when loading orders fails',
        build: () {
          when(() => mockRepository.getMyOrders(page: any(named: 'page')))
              .thenAnswer(
            (_) async => const Left(
              ServerFailure(message: 'Server error'),
            ),
          );
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadMyOrders()),
        expect: () => [
          OrdersLoading(),
          const OrdersError('Server error'),
        ],
        verify: (_) {
          verify(() => mockRepository.getMyOrders(page: 1)).called(1);
        },
      );

      blocTest<OrdersBloc, OrdersState>(
        'emits OrdersLoaded with hasMorePages=true when 20 orders are returned',
        build: () {
          final twentyOrders = List.generate(
            20,
            (index) => OrderEntity(
              id: 'order-$index',
              orderNumber: '${12345 + index}',
              customerId: 'customer-1',
              restaurantId: 'restaurant-1',
              status: OrderStatus.pending,
              totalAmount: 25.50,
              commissionAmount: 0.10,
              paymentStatus: PaymentStatus.paid,
              paymentMethod: 'card',
              estimatedPreparationTime: 20,
              scheduledPickupTime:
                  DateTime.now().add(const Duration(minutes: 30)),
              createdAt: DateTime.now(),
              items: const [],
            ),
          );

          when(() => mockRepository.getMyOrders(page: any(named: 'page')))
              .thenAnswer((_) async => Right(twentyOrders));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadMyOrders()),
        expect: () => [
          OrdersLoading(),
          isA<OrdersLoaded>()
              .having((state) => state.hasMorePages, 'hasMorePages', true)
              .having((state) => state.orders.length, 'orders length', 20),
        ],
      );
    });

    group('CreateOrder', () {
      final tParams = CreateOrderParams(
        restaurantId: 'restaurant-1',
        items: [
          OrderItemParams(productId: 'product-1', quantity: 2),
        ],
        totalAmount: 25.50,
        scheduledPickupTime: DateTime.now().add(const Duration(minutes: 30)),
        paymentMethodId: 'pm_test_123',
      );

      final tCreatedOrder = OrderEntity(
        id: 'order-new',
        orderNumber: '99999',
        customerId: 'customer-1',
        restaurantId: 'restaurant-1',
        status: OrderStatus.pending,
        totalAmount: 25.50,
        commissionAmount: 0.10,
        paymentStatus: PaymentStatus.paid,
        paymentMethod: 'card',
        estimatedPreparationTime: 20,
        scheduledPickupTime: DateTime.now().add(const Duration(minutes: 30)),
        createdAt: DateTime.now(),
        items: const [],
      );

      blocTest<OrdersBloc, OrdersState>(
        'emits [OrderCreating, OrderCreated] when order creation succeeds',
        build: () {
          when(() => mockCreateOrderUseCase(any()))
              .thenAnswer((_) async => Right(tCreatedOrder));
          return bloc;
        },
        act: (bloc) => bloc.add(CreateOrder(tParams)),
        expect: () => [
          OrderCreating(),
          OrderCreated(tCreatedOrder),
        ],
        verify: (_) {
          verify(() => mockCreateOrderUseCase(tParams)).called(1);
        },
      );

      blocTest<OrdersBloc, OrdersState>(
        'emits [OrderCreating, OrdersError] when order creation fails',
        build: () {
          when(() => mockCreateOrderUseCase(any())).thenAnswer(
            (_) async => const Left(
              ValidationFailure(message: 'Validation failed'),
            ),
          );
          return bloc;
        },
        act: (bloc) => bloc.add(CreateOrder(tParams)),
        expect: () => [
          OrderCreating(),
          const OrdersError('Validation failed'),
        ],
      );
    });

    group('CancelOrder', () {
      final tCancelledOrder = OrderEntity(
        id: 'order-1',
        orderNumber: '12345',
        customerId: 'customer-1',
        restaurantId: 'restaurant-1',
        status: OrderStatus.cancelled,
        totalAmount: 25.50,
        commissionAmount: 0.10,
        paymentStatus: PaymentStatus.refunded,
        paymentMethod: 'card',
        estimatedPreparationTime: 20,
        scheduledPickupTime: DateTime.now().add(const Duration(minutes: 30)),
        createdAt: DateTime.now(),
        items: const [],
      );

      blocTest<OrdersBloc, OrdersState>(
        'calls repository.cancelOrder and refreshes orders',
        build: () {
          when(() => mockRepository.cancelOrder(any()))
              .thenAnswer((_) async => Right(tCancelledOrder));
          when(() => mockRepository.getMyOrders(page: any(named: 'page')))
              .thenAnswer((_) async => Right(tOrders));
          return bloc;
        },
        act: (bloc) => bloc.add(const CancelOrder('order-1')),
        expect: () => [
          OrdersLoading(),
          isA<OrdersLoaded>(),
        ],
        verify: (_) {
          verify(() => mockRepository.cancelOrder('order-1')).called(1);
          verify(() => mockRepository.getMyOrders(page: 1)).called(1);
        },
      );

      blocTest<OrdersBloc, OrdersState>(
        'emits OrdersError when cancellation fails',
        build: () {
          when(() => mockRepository.cancelOrder(any())).thenAnswer(
            (_) async => const Left(
              ServerFailure(message: 'Cannot cancel order'),
            ),
          );
          return bloc;
        },
        act: (bloc) => bloc.add(const CancelOrder('order-1')),
        expect: () => [
          const OrdersError('Cannot cancel order'),
        ],
      );
    });

    group('RefreshOrders', () {
      blocTest<OrdersBloc, OrdersState>(
        'triggers LoadMyOrders with page 1',
        build: () {
          when(() => mockRepository.getMyOrders(page: any(named: 'page')))
              .thenAnswer((_) async => Right(tOrders));
          return bloc;
        },
        act: (bloc) => bloc.add(const RefreshOrders()),
        expect: () => [
          OrdersLoading(),
          isA<OrdersLoaded>(),
        ],
        verify: (_) {
          verify(() => mockRepository.getMyOrders(page: 1)).called(1);
        },
      );
    });
  });
}
