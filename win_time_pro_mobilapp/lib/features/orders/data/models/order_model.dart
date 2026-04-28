import '../../domain/entities/order_entity.dart';

class OrderModel extends OrderEntity {
  const OrderModel({
    required super.id,
    required super.orderNumber,
    required super.restaurantId,
    required super.customerId,
    required super.customerInfo,
    required super.items,
    required super.subtotal,
    required super.taxAmount,
    required super.totalAmount,
    required super.status,
    required super.paymentStatus,
    required super.paymentMethod,
    required super.orderDate,
    super.scheduledPickupTime,
    super.acceptedAt,
    super.readyAt,
    super.completedAt,
    super.cancelledAt,
    required super.estimatedPreparationTime,
    super.actualPreparationTime,
    super.specialInstructions,
    super.cancellationReason,
    super.isPaid,
    super.isRated,
    super.rating,
    super.review,
    required super.createdAt,
    required super.updatedAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      restaurantId: json['restaurant_id'] as String,
      customerId: json['customer_id'] as String,
      customerInfo: CustomerInfo(
        name: (json['customer_info'] as Map<String, dynamic>)['name'] as String,
        phoneNumber:
            (json['customer_info'] as Map<String, dynamic>)['phone_number'] as String,
        email: (json['customer_info'] as Map<String, dynamic>)['email'] as String?,
      ),
      items: (json['items'] as List<dynamic>)
          .map((e) => _itemFromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      taxAmount: (json['tax_amount'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: _parseStatus(json['status'] as String),
      paymentStatus: _parsePaymentStatus(json['payment_status'] as String),
      paymentMethod: _parsePaymentMethod(json['payment_method'] as String),
      orderDate: DateTime.parse(json['order_date'] as String),
      scheduledPickupTime: json['scheduled_pickup_time'] != null
          ? DateTime.parse(json['scheduled_pickup_time'] as String)
          : null,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      readyAt: json['ready_at'] != null
          ? DateTime.parse(json['ready_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      estimatedPreparationTime: json['estimated_preparation_time'] as int? ?? 0,
      actualPreparationTime: json['actual_preparation_time'] as int?,
      specialInstructions: json['special_instructions'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
      isRated: json['is_rated'] as bool? ?? false,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      review: json['review'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static OrderItem _itemFromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'] as String,
        productId: json['product_id'] as String,
        productName: json['product_name'] as String,
        productImageUrl: json['product_image_url'] as String?,
        quantity: json['quantity'] as int,
        unitPrice: (json['unit_price'] as num).toDouble(),
        totalPrice: (json['total_price'] as num).toDouble(),
        selectedSize: json['selected_size'] as String?,
        selectedOptions: (json['selected_options'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        modifications: (json['modifications'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        specialInstructions: json['special_instructions'] as String?,
      );

  static OrderStatus _parseStatus(String value) {
    switch (value) {
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
      case 'rejected':
        return OrderStatus.rejected;
      default:
        return OrderStatus.pending;
    }
  }

  static PaymentStatus _parsePaymentStatus(String value) {
    switch (value) {
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

  static PaymentMethod _parsePaymentMethod(String value) {
    switch (value) {
      case 'cash':
        return PaymentMethod.cash;
      case 'paypal':
        return PaymentMethod.paypal;
      case 'apple_pay':
        return PaymentMethod.applePay;
      case 'google_pay':
        return PaymentMethod.googlePay;
      case 'credit_card':
        return PaymentMethod.creditCard;
      default:
        return PaymentMethod.other;
    }
  }
}
