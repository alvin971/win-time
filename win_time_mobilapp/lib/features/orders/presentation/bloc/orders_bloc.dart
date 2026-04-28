import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/usecases/create_order_usecase.dart';
import 'orders_event.dart';
import 'orders_state.dart';

@injectable
class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  final OrderRepository orderRepository;
  final CreateOrderUseCase createOrderUseCase;

  OrdersBloc({
    required this.orderRepository,
    required this.createOrderUseCase,
  }) : super(OrdersInitial()) {
    on<LoadMyOrders>(_onLoadMyOrders);
    on<CreateOrder>(_onCreateOrder);
    on<CancelOrder>(_onCancelOrder);
    on<RefreshOrders>(_onRefreshOrders);
  }

  Future<void> _onLoadMyOrders(
    LoadMyOrders event,
    Emitter<OrdersState> emit,
  ) async {
    if (event.page == 1) {
      emit(OrdersLoading());
    }

    final result = await orderRepository.getMyOrders(page: event.page);

    result.fold(
      (failure) => emit(OrdersError(failure.message)),
      (orders) {
        final currentOrders = state is OrdersLoaded
            ? (state as OrdersLoaded).orders
            : <OrderEntity>[];

        final allOrders = event.page == 1
            ? orders
            : [...currentOrders, ...orders];

        emit(OrdersLoaded(
          orders: allOrders,
          hasMorePages: orders.length == 20,
          currentPage: event.page,
        ));
      },
    );
  }

  Future<void> _onCreateOrder(
    CreateOrder event,
    Emitter<OrdersState> emit,
  ) async {
    emit(OrderCreating());

    final result = await createOrderUseCase(event.params);

    result.fold(
      (failure) => emit(OrdersError(failure.message)),
      (order) => emit(OrderCreated(order)),
    );
  }

  Future<void> _onCancelOrder(
    CancelOrder event,
    Emitter<OrdersState> emit,
  ) async {
    final result = await orderRepository.cancelOrder(event.orderId);

    result.fold(
      (failure) => emit(OrdersError(failure.message)),
      (cancelledOrder) {
        // Refresh orders après annulation
        add(const RefreshOrders());
      },
    );
  }

  Future<void> _onRefreshOrders(
    RefreshOrders event,
    Emitter<OrdersState> emit,
  ) async {
    add(const LoadMyOrders(page: 1));
  }
}
