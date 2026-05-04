import '../../domain/entities/order_entity.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/enums/payment_method.dart';
import '../../domain/enums/payment_status.dart';
import '_helpers.dart';

/// Mapper Postgres ↔ [OrderEntity].
///
/// Table : `wintime.orders`. Les champs `customer_info` et `items` sont
/// stockés en JSONB (snapshot figé au moment de la création).
///
/// IMPORTANT: ne redéfinit PAS [OrderEntity] (déjà dans `domain/entities/`).
class OrderModel {
  static OrderEntity fromRow(Map<String, dynamic> row) {
    return OrderEntity(
      id: row['id'] as String,
      orderNumber: (row['order_number'] as String?) ?? (row['id'] as String),
      restaurantId: (row['restaurant_id'] as String?) ?? '',
      customerId: (row['customer_id'] as String?) ?? '',
      customerInfo: _customerInfoFromMap(row['customer_info']),
      items: asList<dynamic>(row['items']).map(_itemFromMap).toList(),
      subtotal: asDouble(row['subtotal']) ?? 0.0,
      taxAmount: asDouble(row['tax_amount']) ?? 0.0,
      totalAmount: asDouble(row['total_amount']) ?? 0.0,
      commissionAmount: asDouble(row['commission_amount']),
      status: _statusFromString(row['status'] as String?),
      paymentStatus: _paymentStatusFromString(row['payment_status'] as String?),
      paymentMethod: _paymentMethodFromString(row['payment_method'] as String?),
      createdAt: ts(row['created_at']) ?? DateTime.now(),
      scheduledPickupTime: ts(row['scheduled_pickup_time']),
      acceptedAt: ts(row['accepted_at']),
      readyAt: ts(row['ready_at']),
      completedAt: ts(row['completed_at']),
      cancelledAt: ts(row['cancelled_at']),
      estimatedPreparationTime: asInt(row['estimated_preparation_time']) ?? 30,
      actualPreparationTime: asInt(row['actual_preparation_time']),
      specialInstructions: row['special_instructions'] as String?,
      cancellationReason: row['cancellation_reason'] as String?,
      isPaid: (row['is_paid'] as bool?) ?? false,
      isRated: (row['is_rated'] as bool?) ?? false,
      rating: asDouble(row['rating']),
      review: row['review'] as String?,
      updatedAt: ts(row['updated_at']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> toRow(OrderEntity o) {
    return {
      if (o.id.isNotEmpty) 'id': o.id,
      'order_number': o.orderNumber,
      'restaurant_id': o.restaurantId,
      'customer_id': o.customerId,
      'customer_info':
          o.customerInfo != null ? _customerInfoToMap(o.customerInfo!) : null,
      'items': o.items.map(_itemToMap).toList(),
      'subtotal': o.subtotal,
      'tax_amount': o.taxAmount,
      'total_amount': o.totalAmount,
      'commission_amount': o.commissionAmount,
      'status': o.status.name,
      'payment_status': o.paymentStatus.name,
      'payment_method': o.paymentMethod.name,
      'scheduled_pickup_time': tsString(o.scheduledPickupTime),
      'accepted_at': tsString(o.acceptedAt),
      'ready_at': tsString(o.readyAt),
      'completed_at': tsString(o.completedAt),
      'cancelled_at': tsString(o.cancelledAt),
      'estimated_preparation_time': o.estimatedPreparationTime,
      'actual_preparation_time': o.actualPreparationTime,
      'special_instructions': o.specialInstructions,
      'cancellation_reason': o.cancellationReason,
      'is_paid': o.isPaid,
      'is_rated': o.isRated,
      'rating': o.rating,
      'review': o.review,
    };
  }

  // ─── CustomerInfo ────────────────────────────────────────────────────────
  static CustomerInfo? _customerInfoFromMap(dynamic raw) {
    if (raw is! Map) return null;
    return CustomerInfo(
      name: (raw['name'] as String?) ?? '',
      // Lecture défensive : snake_case (canonique) puis camelCase (legacy).
      phoneNumber:
          (raw['phone_number'] ?? raw['phoneNumber'] ?? '').toString(),
      email: raw['email'] as String?,
    );
  }

  static Map<String, dynamic> _customerInfoToMap(CustomerInfo c) => {
        // Snake_case canonique (lu par Pro OrderModel.fromJson en priorité,
        // avec fallback camelCase pour les orders pré-fix).
        'name': c.name,
        'phone_number': c.phoneNumber,
        'email': c.email,
      };

  // ─── OrderItemEntity ─────────────────────────────────────────────────────
  static OrderItemEntity _itemFromMap(dynamic raw) {
    if (raw is! Map) {
      return const OrderItemEntity(
        id: '',
        productId: '',
        productName: '',
        quantity: 0,
        unitPrice: 0,
        totalPrice: 0,
      );
    }
    // Lecture défensive : snake_case (canonique) puis camelCase (legacy).
    String pick(String snake, String camel) =>
        ((raw[snake] ?? raw[camel]) ?? '').toString();
    String? pickN(String snake, String camel) =>
        (raw[snake] ?? raw[camel]) as String?;
    return OrderItemEntity(
      id: (raw['id'] as String?) ?? '',
      productId: pick('product_id', 'productId'),
      productName: pick('product_name', 'productName'),
      productImageUrl: pickN('product_image_url', 'productImageUrl'),
      quantity: asInt(raw['quantity']) ?? 1,
      unitPrice: asDouble(raw['unit_price'] ?? raw['unitPrice']) ?? 0.0,
      totalPrice: asDouble(raw['total_price'] ?? raw['totalPrice']) ?? 0.0,
      selectedSize: pickN('selected_size', 'selectedSize'),
      selectedOptions:
          asList<String>(raw['selected_options'] ?? raw['selectedOptions']),
      modifications: asList<String>(raw['modifications']),
      specialInstructions:
          pickN('special_instructions', 'specialInstructions'),
    );
  }

  static Map<String, dynamic> _itemToMap(OrderItemEntity i) => {
        // Snake_case canonique (cf. _customerInfoToMap).
        'id': i.id,
        'product_id': i.productId,
        'product_name': i.productName,
        'product_image_url': i.productImageUrl,
        'quantity': i.quantity,
        'unit_price': i.unitPrice,
        'total_price': i.totalPrice,
        'selected_size': i.selectedSize,
        'selected_options': i.selectedOptions,
        'modifications': i.modifications,
        'special_instructions': i.specialInstructions,
      };

  // ─── Enums ───────────────────────────────────────────────────────────────
  static OrderStatus _statusFromString(String? raw) {
    if (raw == null) return OrderStatus.pending;
    return OrderStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => OrderStatus.pending,
    );
  }

  static PaymentStatus _paymentStatusFromString(String? raw) {
    if (raw == null) return PaymentStatus.pending;
    return PaymentStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => PaymentStatus.pending,
    );
  }

  static PaymentMethod _paymentMethodFromString(String? raw) {
    if (raw == null) return PaymentMethod.creditCard;
    return PaymentMethod.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => PaymentMethod.creditCard,
    );
  }
}
