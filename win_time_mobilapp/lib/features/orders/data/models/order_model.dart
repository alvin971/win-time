import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/order_entity.dart';

part 'order_model.g.dart';

@JsonSerializable(explicitToJson: true)
class OrderModel {
  final String id;
  @JsonKey(name: 'order_number')
  final String orderNumber;
  @JsonKey(name: 'customer_id')
  final String customerId;
  @JsonKey(name: 'restaurant_id')
  final String restaurantId;
  final String status;
  @JsonKey(name: 'total_amount')
  final double totalAmount;
  @JsonKey(name: 'commission_amount')
  final double commissionAmount;
  @JsonKey(name: 'payment_status')
  final String paymentStatus;
  @JsonKey(name: 'payment_method')
  final String paymentMethod;
  @JsonKey(name: 'estimated_preparation_time')
  final int estimatedPreparationTime;
  @JsonKey(name: 'actual_preparation_time')
  final int? actualPreparationTime;
  @JsonKey(name: 'scheduled_pickup_time')
  final DateTime scheduledPickupTime;
  @JsonKey(name: 'actual_pickup_time')
  final DateTime? actualPickupTime;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'accepted_at')
  final DateTime? acceptedAt;
  @JsonKey(name: 'ready_at')
  final DateTime? readyAt;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  @JsonKey(name: 'special_instructions')
  final String? specialInstructions;
  @JsonKey(name: 'cancellation_reason')
  final String? cancellationReason;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.restaurantId,
    required this.status,
    required this.totalAmount,
    required this.commissionAmount,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.estimatedPreparationTime,
    this.actualPreparationTime,
    required this.scheduledPickupTime,
    this.actualPickupTime,
    required this.createdAt,
    this.acceptedAt,
    this.readyAt,
    this.completedAt,
    this.specialInstructions,
    this.cancellationReason,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderModelFromJson(json);

  Map<String, dynamic> toJson() => _$OrderModelToJson(this);

  /// Conversion vers l'entité domain
  OrderEntity toEntity() {
    return OrderEntity(
      id: id,
      orderNumber: orderNumber,
      customerId: customerId,
      restaurantId: restaurantId,
      status: _parseOrderStatus(status),
      totalAmount: totalAmount,
      commissionAmount: commissionAmount,
      paymentStatus: _parsePaymentStatus(paymentStatus),
      paymentMethod: paymentMethod,
      estimatedPreparationTime: estimatedPreparationTime,
      actualPreparationTime: actualPreparationTime,
      scheduledPickupTime: scheduledPickupTime,
      actualPickupTime: actualPickupTime,
      createdAt: createdAt,
      acceptedAt: acceptedAt,
      readyAt: readyAt,
      completedAt: completedAt,
      specialInstructions: specialInstructions,
      cancellationReason: cancellationReason,
      items: items.map((item) => item.toEntity()).toList(),
    );
  }

  OrderStatus _parseOrderStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'accepted':
        return OrderStatus.accepted;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  PaymentStatus _parsePaymentStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return PaymentStatus.pending;
    }
  }
}

@JsonSerializable()
class OrderItemModel {
  final String id;
  @JsonKey(name: 'product_id')
  final String productId;
  @JsonKey(name: 'product_name')
  final String productName;
  final int quantity;
  @JsonKey(name: 'unit_price')
  final double unitPrice;
  @JsonKey(name: 'total_price')
  final double totalPrice;
  @JsonKey(name: 'options_selected')
  final Map<String, dynamic>? optionsSelected;
  @JsonKey(name: 'special_notes')
  final String? specialNotes;

  OrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.optionsSelected,
    this.specialNotes,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) =>
      _$OrderItemModelFromJson(json);

  Map<String, dynamic> toJson() => _$OrderItemModelToJson(this);

  OrderItemEntity toEntity() {
    return OrderItemEntity(
      id: id,
      productId: productId,
      productName: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      optionsSelected: optionsSelected,
      specialNotes: specialNotes,
    );
  }
}
