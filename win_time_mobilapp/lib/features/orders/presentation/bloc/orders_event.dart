import 'package:equatable/equatable.dart';
import '../../domain/usecases/create_order_usecase.dart';

abstract class OrdersEvent extends Equatable {
  const OrdersEvent();

  @override
  List<Object?> get props => [];
}

class LoadMyOrders extends OrdersEvent {
  final int page;

  const LoadMyOrders({this.page = 1});

  @override
  List<Object?> get props => [page];
}

class CreateOrder extends OrdersEvent {
  final CreateOrderParams params;

  const CreateOrder(this.params);

  @override
  List<Object?> get props => [params];
}

class CancelOrder extends OrdersEvent {
  final String orderId;

  const CancelOrder(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class RefreshOrders extends OrdersEvent {
  const RefreshOrders();
}
