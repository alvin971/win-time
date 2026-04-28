import 'package:equatable/equatable.dart';

class OrderEntity extends Equatable {
  final String id;
  final String orderNumber;
  final String restaurantId;
  final String customerId;
  final CustomerInfo customerInfo;

  final List<OrderItem> items;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;

  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final PaymentMethod paymentMethod;

  final DateTime orderDate;
  final DateTime? scheduledPickupTime;
  final DateTime? acceptedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  final int estimatedPreparationTime;
  final int? actualPreparationTime;

  final String? specialInstructions;
  final String? cancellationReason;

  final bool isPaid;
  final bool isRated;
  final double? rating;
  final String? review;

  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderEntity({
    required this.id,
    required this.orderNumber,
    required this.restaurantId,
    required this.customerId,
    required this.customerInfo,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.orderDate,
    this.scheduledPickupTime,
    this.acceptedAt,
    this.readyAt,
    this.completedAt,
    this.cancelledAt,
    required this.estimatedPreparationTime,
    this.actualPreparationTime,
    this.specialInstructions,
    this.cancellationReason,
    this.isPaid = false,
    this.isRated = false,
    this.rating,
    this.review,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get canBeAccepted => status == OrderStatus.pending;
  bool get canBeRejected => status == OrderStatus.pending || status == OrderStatus.accepted;
  bool get canBeMarkedReady => status == OrderStatus.preparing;
  bool get canBeCompleted => status == OrderStatus.ready;
  bool get isActive => status == OrderStatus.pending ||
                      status == OrderStatus.accepted ||
                      status == OrderStatus.preparing ||
                      status == OrderStatus.ready;

  Duration? get preparationDuration {
    if (acceptedAt != null && readyAt != null) {
      return readyAt!.difference(acceptedAt!);
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        orderNumber,
        restaurantId,
        customerId,
        customerInfo,
        items,
        subtotal,
        taxAmount,
        totalAmount,
        status,
        paymentStatus,
        paymentMethod,
        orderDate,
        scheduledPickupTime,
        acceptedAt,
        readyAt,
        completedAt,
        cancelledAt,
        estimatedPreparationTime,
        actualPreparationTime,
        specialInstructions,
        cancellationReason,
        isPaid,
        isRated,
        rating,
        review,
        createdAt,
        updatedAt,
      ];
}

class OrderItem extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final String? productImageUrl;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  final String? selectedSize;
  final List<String> selectedOptions;
  final List<String> modifications;
  final String? specialInstructions;

  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.selectedSize,
    this.selectedOptions = const [],
    this.modifications = const [],
    this.specialInstructions,
  });

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        productImageUrl,
        quantity,
        unitPrice,
        totalPrice,
        selectedSize,
        selectedOptions,
        modifications,
        specialInstructions,
      ];
}

class CustomerInfo extends Equatable {
  final String name;
  final String phoneNumber;
  final String? email;

  const CustomerInfo({
    required this.name,
    required this.phoneNumber,
    this.email,
  });

  @override
  List<Object?> get props => [name, phoneNumber, email];
}

enum OrderStatus {
  pending,
  accepted,
  preparing,
  ready,
  completed,
  cancelled,
  rejected,
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
}

enum PaymentMethod {
  creditCard,
  cash,
  paypal,
  applePay,
  googlePay,
  other,
}
