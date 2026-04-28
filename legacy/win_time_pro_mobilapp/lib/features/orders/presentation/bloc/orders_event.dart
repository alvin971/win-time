import 'package:equatable/equatable.dart';
import '../../domain/entities/order_entity.dart';

abstract class OrdersEvent extends Equatable {
  const OrdersEvent();

  @override
  List<Object?> get props => [];
}

class OrdersLoadActiveRequested extends OrdersEvent {
  final String restaurantId;

  const OrdersLoadActiveRequested({required this.restaurantId});

  @override
  List<Object?> get props => [restaurantId];
}

class OrdersLoadHistoryRequested extends OrdersEvent {
  final String restaurantId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;
  final int? offset;

  const OrdersLoadHistoryRequested({
    required this.restaurantId,
    this.startDate,
    this.endDate,
    this.limit,
    this.offset,
  });

  @override
  List<Object?> get props => [restaurantId, startDate, endDate, limit, offset];
}

class OrderAcceptRequested extends OrdersEvent {
  final String orderId;
  final int? estimatedPreparationTime;

  const OrderAcceptRequested({
    required this.orderId,
    this.estimatedPreparationTime,
  });

  @override
  List<Object?> get props => [orderId, estimatedPreparationTime];
}

class OrderRejectRequested extends OrdersEvent {
  final String orderId;
  final String reason;

  const OrderRejectRequested({
    required this.orderId,
    required this.reason,
  });

  @override
  List<Object?> get props => [orderId, reason];
}

class OrderMarkReadyRequested extends OrdersEvent {
  final String orderId;

  const OrderMarkReadyRequested({required this.orderId});

  @override
  List<Object?> get props => [orderId];
}

class OrderCompleteRequested extends OrdersEvent {
  final String orderId;

  const OrderCompleteRequested({required this.orderId});

  @override
  List<Object?> get props => [orderId];
}

class OrderNewReceived extends OrdersEvent {
  final OrderEntity order;

  const OrderNewReceived({required this.order});

  @override
  List<Object?> get props => [order];
}

class OrdersRefreshRequested extends OrdersEvent {
  final String restaurantId;

  const OrdersRefreshRequested({required this.restaurantId});

  @override
  List<Object?> get props => [restaurantId];
}
