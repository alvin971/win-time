import 'package:equatable/equatable.dart';
import '../../domain/entities/order_entity.dart';

abstract class OrdersState extends Equatable {
  const OrdersState();

  @override
  List<Object?> get props => [];
}

class OrdersInitial extends OrdersState {}

class OrdersLoading extends OrdersState {}

class OrdersLoaded extends OrdersState {
  final List<OrderEntity> orders;
  final bool hasMorePages;
  final int currentPage;

  const OrdersLoaded({
    required this.orders,
    this.hasMorePages = false,
    this.currentPage = 1,
  });

  @override
  List<Object?> get props => [orders, hasMorePages, currentPage];

  OrdersLoaded copyWith({
    List<OrderEntity>? orders,
    bool? hasMorePages,
    int? currentPage,
  }) {
    return OrdersLoaded(
      orders: orders ?? this.orders,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class OrderCreating extends OrdersState {}

class OrderCreated extends OrdersState {
  final OrderEntity order;

  const OrderCreated(this.order);

  @override
  List<Object?> get props => [order];
}

class OrdersError extends OrdersState {
  final String message;

  const OrdersError(this.message);

  @override
  List<Object?> get props => [message];
}
