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

  // Helpers défensifs : tolèrent snake_case OU camelCase (compat orders
  // existantes pré-fix) + null-safe avec fallback.
  static String _str(Map<String, dynamic> m, List<String> keys, [String fallback = '']) {
    for (final k in keys) {
      final v = m[k];
      if (v != null) return v.toString();
    }
    return fallback;
  }

  static String? _strOrNull(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null) return v.toString();
    }
    return null;
  }

  static double _num(Map<String, dynamic> m, List<String> keys, [double fallback = 0.0]) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
    }
    return fallback;
  }

  static int _int(Map<String, dynamic> m, List<String> keys, [int fallback = 0]) {
    for (final k in keys) {
      final v = m[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
    }
    return fallback;
  }

  static DateTime? _dateOrNull(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final ci = (json['customer_info'] as Map?)?.cast<String, dynamic>() ?? const {};
    final now = DateTime.now();
    return OrderModel(
      id: _str(json, ['id']),
      orderNumber: _str(json, ['order_number', 'orderNumber']),
      restaurantId: _str(json, ['restaurant_id', 'restaurantId']),
      customerId: _str(json, ['customer_id', 'customerId']),
      customerInfo: CustomerInfo(
        name: _str(ci, ['name']),
        phoneNumber: _str(ci, ['phone_number', 'phoneNumber']),
        email: _strOrNull(ci, ['email']),
      ),
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => _itemFromJson(e.cast<String, dynamic>()))
          .toList(),
      subtotal: _num(json, ['subtotal']),
      taxAmount: _num(json, ['tax_amount', 'taxAmount']),
      totalAmount: _num(json, ['total_amount', 'totalAmount']),
      status: _parseStatus(_str(json, ['status'], 'pending')),
      paymentStatus: _parsePaymentStatus(_str(json, ['payment_status', 'paymentStatus'], 'pending')),
      paymentMethod: _parsePaymentMethod(_str(json, ['payment_method', 'paymentMethod'], 'cash')),
      orderDate: _dateOrNull(json['order_date'] ?? json['created_at']) ?? now,
      scheduledPickupTime: _dateOrNull(json['scheduled_pickup_time'] ?? json['scheduledPickupTime']),
      acceptedAt: _dateOrNull(json['accepted_at'] ?? json['acceptedAt']),
      readyAt: _dateOrNull(json['ready_at'] ?? json['readyAt']),
      completedAt: _dateOrNull(json['completed_at'] ?? json['completedAt']),
      cancelledAt: _dateOrNull(json['cancelled_at'] ?? json['cancelledAt']),
      estimatedPreparationTime: _int(json, ['estimated_preparation_time', 'estimatedPreparationTime'], 30),
      actualPreparationTime: json['actual_preparation_time'] is int
          ? json['actual_preparation_time'] as int
          : (json['actualPreparationTime'] as int?),
      specialInstructions: _strOrNull(json, ['special_instructions', 'specialInstructions']),
      cancellationReason: _strOrNull(json, ['cancellation_reason', 'cancellationReason']),
      isPaid: (json['is_paid'] ?? json['isPaid'] ?? false) as bool,
      isRated: (json['is_rated'] ?? json['isRated'] ?? false) as bool,
      rating: json['rating'] is num ? (json['rating'] as num).toDouble() : null,
      review: _strOrNull(json, ['review']),
      createdAt: _dateOrNull(json['created_at'] ?? json['createdAt']) ?? now,
      updatedAt: _dateOrNull(json['updated_at'] ?? json['updatedAt']) ?? now,
    );
  }

  static OrderItem _itemFromJson(Map<String, dynamic> json) => OrderItem(
        id: _str(json, ['id']),
        productId: _str(json, ['product_id', 'productId']),
        productName: _str(json, ['product_name', 'productName']),
        productImageUrl: _strOrNull(json, ['product_image_url', 'productImageUrl']),
        quantity: _int(json, ['quantity'], 1),
        unitPrice: _num(json, ['unit_price', 'unitPrice']),
        totalPrice: _num(json, ['total_price', 'totalPrice']),
        selectedSize: _strOrNull(json, ['selected_size', 'selectedSize']),
        selectedOptions:
            ((json['selected_options'] ?? json['selectedOptions']) as List?)
                    ?.whereType<String>()
                    .toList() ??
                const [],
        modifications: (json['modifications'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
        specialInstructions: _strOrNull(json, ['special_instructions', 'specialInstructions']),
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
