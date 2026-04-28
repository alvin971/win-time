import 'package:equatable/equatable.dart';
import '../../domain/entities/order_entity.dart';

abstract class OrdersState extends Equatable {
  const OrdersState();

  @override
  List<Object?> get props => [];
}

class OrdersInitial extends OrdersState {
  const OrdersInitial();
}

class OrdersLoading extends OrdersState {
  const OrdersLoading();
}

class OrdersLoaded extends OrdersState {
  final List<OrderEntity> orders;

  const OrdersLoaded({required this.orders});

  List<OrderEntity> get pendingOrders =>
      orders.where((order) => order.status == OrderStatus.pending).toList();

  List<OrderEntity> get acceptedOrders =>
      orders.where((order) => order.status == OrderStatus.accepted).toList();

  List<OrderEntity> get preparingOrders =>
      orders.where((order) => order.status == OrderStatus.preparing).toList();

  List<OrderEntity> get readyOrders =>
      orders.where((order) => order.status == OrderStatus.ready).toList();

  @override
  List<Object?> get props => [orders];
}

class OrdersHistoryLoaded extends OrdersState {
  final List<OrderEntity> orders;

  const OrdersHistoryLoaded({required this.orders});

  @override
  List<Object?> get props => [orders];
}

class OrdersActionInProgress extends OrdersState {
  final List<OrderEntity> orders;

  const OrdersActionInProgress({required this.orders});

  @override
  List<Object?> get props => [orders];
}

class OrderActionSuccess extends OrdersState {
  final String message;
  final List<OrderEntity> orders;

  const OrderActionSuccess({
    required this.message,
    required this.orders,
  });

  @override
  List<Object?> get props => [message, orders];
}

class OrderNewReceivedNotification extends OrdersState {
  final OrderEntity order;
  final List<OrderEntity> orders;

  const OrderNewReceivedNotification({
    required this.order,
    required this.orders,
  });

  @override
  List<Object?> get props => [order, orders];
}

class OrdersError extends OrdersState {
  final String message;

  const OrdersError({required this.message});

  @override
  List<Object?> get props => [message];
}
