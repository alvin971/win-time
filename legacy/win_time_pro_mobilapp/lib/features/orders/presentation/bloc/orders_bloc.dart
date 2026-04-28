import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import 'orders_event.dart';
import 'orders_state.dart';

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  final OrderRepository _orderRepository;

  OrdersBloc({required OrderRepository orderRepository})
      : _orderRepository = orderRepository,
        super(const OrdersInitial()) {
    on<OrdersLoadActiveRequested>(_onOrdersLoadActiveRequested);
    on<OrdersLoadHistoryRequested>(_onOrdersLoadHistoryRequested);
    on<OrderAcceptRequested>(_onOrderAcceptRequested);
    on<OrderRejectRequested>(_onOrderRejectRequested);
    on<OrderMarkReadyRequested>(_onOrderMarkReadyRequested);
    on<OrderCompleteRequested>(_onOrderCompleteRequested);
    on<OrderNewReceived>(_onOrderNewReceived);
    on<OrdersRefreshRequested>(_onOrdersRefreshRequested);
  }

  Future<void> _onOrdersLoadActiveRequested(
    OrdersLoadActiveRequested event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());

    final result = await _orderRepository.getActiveOrders(
      restaurantId: event.restaurantId,
    );

    result.fold(
      (failure) => emit(OrdersError(message: failure.message)),
      (orders) => emit(OrdersLoaded(orders: orders)),
    );
  }

  Future<void> _onOrdersLoadHistoryRequested(
    OrdersLoadHistoryRequested event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());

    final result = await _orderRepository.getOrderHistory(
      restaurantId: event.restaurantId,
      startDate: event.startDate,
      endDate: event.endDate,
      limit: event.limit,
      offset: event.offset,
    );

    result.fold(
      (failure) => emit(OrdersError(message: failure.message)),
      (orders) => emit(OrdersHistoryLoaded(orders: orders)),
    );
  }

  Future<void> _onOrderAcceptRequested(
    OrderAcceptRequested event,
    Emitter<OrdersState> emit,
  ) async {
    if (state is OrdersLoaded) {
      final currentState = state as OrdersLoaded;
      emit(OrdersActionInProgress(orders: currentState.orders));

      final result = await _orderRepository.acceptOrder(
        orderId: event.orderId,
        estimatedPreparationTime: event.estimatedPreparationTime,
      );

      result.fold(
        (failure) => emit(OrdersError(message: failure.message)),
        (updatedOrder) {
          final updatedOrders = currentState.orders
              .map((order) => order.id == updatedOrder.id ? updatedOrder : order)
              .toList();
          emit(OrdersLoaded(orders: updatedOrders));
          emit(OrderActionSuccess(
            message: 'Commande acceptée avec succès',
            orders: updatedOrders,
          ));
        },
      );
    }
  }

  Future<void> _onOrderRejectRequested(
    OrderRejectRequested event,
    Emitter<OrdersState> emit,
  ) async {
    if (state is OrdersLoaded) {
      final currentState = state as OrdersLoaded;
      emit(OrdersActionInProgress(orders: currentState.orders));

      final result = await _orderRepository.rejectOrder(
        orderId: event.orderId,
        reason: event.reason,
      );

      result.fold(
        (failure) => emit(OrdersError(message: failure.message)),
        (updatedOrder) {
          final updatedOrders = currentState.orders
              .where((order) => order.id != updatedOrder.id)
              .toList();
          emit(OrdersLoaded(orders: updatedOrders));
          emit(OrderActionSuccess(
            message: 'Commande refusée',
            orders: updatedOrders,
          ));
        },
      );
    }
  }

  Future<void> _onOrderMarkReadyRequested(
    OrderMarkReadyRequested event,
    Emitter<OrdersState> emit,
  ) async {
    if (state is OrdersLoaded) {
      final currentState = state as OrdersLoaded;
      emit(OrdersActionInProgress(orders: currentState.orders));

      final result = await _orderRepository.markOrderReady(
        orderId: event.orderId,
      );

      result.fold(
        (failure) => emit(OrdersError(message: failure.message)),
        (updatedOrder) {
          final updatedOrders = currentState.orders
              .map((order) => order.id == updatedOrder.id ? updatedOrder : order)
              .toList();
          emit(OrdersLoaded(orders: updatedOrders));
          emit(OrderActionSuccess(
            message: 'Commande prête pour le retrait',
            orders: updatedOrders,
          ));
        },
      );
    }
  }

  Future<void> _onOrderCompleteRequested(
    OrderCompleteRequested event,
    Emitter<OrdersState> emit,
  ) async {
    if (state is OrdersLoaded) {
      final currentState = state as OrdersLoaded;
      emit(OrdersActionInProgress(orders: currentState.orders));

      final result = await _orderRepository.completeOrder(
        orderId: event.orderId,
      );

      result.fold(
        (failure) => emit(OrdersError(message: failure.message)),
        (updatedOrder) {
          final updatedOrders = currentState.orders
              .where((order) => order.id != updatedOrder.id)
              .toList();
          emit(OrdersLoaded(orders: updatedOrders));
          emit(OrderActionSuccess(
            message: 'Commande terminée',
            orders: updatedOrders,
          ));
        },
      );
    }
  }

  void _onOrderNewReceived(
    OrderNewReceived event,
    Emitter<OrdersState> emit,
  ) {
    if (state is OrdersLoaded) {
      final currentState = state as OrdersLoaded;
      final updatedOrders = [event.order, ...currentState.orders];
      emit(OrdersLoaded(orders: updatedOrders));
      emit(OrderNewReceivedNotification(
        order: event.order,
        orders: updatedOrders,
      ));
    }
  }

  Future<void> _onOrdersRefreshRequested(
    OrdersRefreshRequested event,
    Emitter<OrdersState> emit,
  ) async {
    final result = await _orderRepository.getActiveOrders(
      restaurantId: event.restaurantId,
    );

    result.fold(
      (failure) {
        if (state is OrdersLoaded) {
          emit(OrdersError(message: failure.message));
        }
      },
      (orders) => emit(OrdersLoaded(orders: orders)),
    );
  }
}
