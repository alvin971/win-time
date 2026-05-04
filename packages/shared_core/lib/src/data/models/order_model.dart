import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/order_entity.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/enums/payment_method.dart';
import '../../domain/enums/payment_status.dart';
import '_helpers.dart';

/// Mapper Firestore ↔ [OrderEntity].
///
/// IMPORTANT: ne redéfinit PAS [OrderEntity] (déjà dans `domain/entities/`).
/// Stocké à `/orders/{oid}`.
class OrderModel {
  static OrderEntity fromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? const <String, dynamic>{};
    return OrderEntity(
      id: snap.id,
      orderNumber: (data['orderNumber'] as String?) ?? snap.id,
      restaurantId: (data['restaurantId'] as String?) ?? '',
      customerId: (data['customerId'] as String?) ?? '',
      customerInfo: _customerInfoFromMap(data['customerInfo']),
      items: asList<dynamic>(data['items']).map(_itemFromMap).toList(),
      subtotal: asDouble(data['subtotal']) ?? 0.0,
      taxAmount: asDouble(data['taxAmount']) ?? 0.0,
      totalAmount: asDouble(data['totalAmount']) ?? 0.0,
      commissionAmount: asDouble(data['commissionAmount']),
      status: _statusFromString(data['status'] as String?),
      paymentStatus: _paymentStatusFromString(data['paymentStatus'] as String?),
      paymentMethod: _paymentMethodFromString(data['paymentMethod'] as String?),
      createdAt: ts(data['createdAt']) ?? DateTime.now(),
      scheduledPickupTime: ts(data['scheduledPickupTime']),
      acceptedAt: ts(data['acceptedAt']),
      readyAt: ts(data['readyAt']),
      completedAt: ts(data['completedAt']),
      cancelledAt: ts(data['cancelledAt']),
      estimatedPreparationTime:
          (data['estimatedPreparationTime'] as int?) ?? 30,
      actualPreparationTime: data['actualPreparationTime'] as int?,
      specialInstructions: data['specialInstructions'] as String?,
      cancellationReason: data['cancellationReason'] as String?,
      isPaid: (data['isPaid'] as bool?) ?? false,
      isRated: (data['isRated'] as bool?) ?? false,
      rating: asDouble(data['rating']),
      review: data['review'] as String?,
      updatedAt: ts(data['updatedAt']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> toFirestore(OrderEntity o) {
    return {
      'orderNumber': o.orderNumber,
      'restaurantId': o.restaurantId,
      'customerId': o.customerId,
      'customerInfo':
          o.customerInfo != null ? _customerInfoToMap(o.customerInfo!) : null,
      'items': o.items.map(_itemToMap).toList(),
      'subtotal': o.subtotal,
      'taxAmount': o.taxAmount,
      'totalAmount': o.totalAmount,
      'commissionAmount': o.commissionAmount,
      'status': o.status.name,
      'paymentStatus': o.paymentStatus.name,
      'paymentMethod': o.paymentMethod.name,
      'createdAt': Timestamp.fromDate(o.createdAt),
      'scheduledPickupTime': o.scheduledPickupTime != null
          ? Timestamp.fromDate(o.scheduledPickupTime!)
          : null,
      'acceptedAt':
          o.acceptedAt != null ? Timestamp.fromDate(o.acceptedAt!) : null,
      'readyAt': o.readyAt != null ? Timestamp.fromDate(o.readyAt!) : null,
      'completedAt':
          o.completedAt != null ? Timestamp.fromDate(o.completedAt!) : null,
      'cancelledAt':
          o.cancelledAt != null ? Timestamp.fromDate(o.cancelledAt!) : null,
      'estimatedPreparationTime': o.estimatedPreparationTime,
      'actualPreparationTime': o.actualPreparationTime,
      'specialInstructions': o.specialInstructions,
      'cancellationReason': o.cancellationReason,
      'isPaid': o.isPaid,
      'isRated': o.isRated,
      'rating': o.rating,
      'review': o.review,
      'updatedAt': Timestamp.fromDate(o.updatedAt),
    };
  }

  // ─── CustomerInfo ────────────────────────────────────────────────────────
  static CustomerInfo? _customerInfoFromMap(dynamic raw) {
    if (raw is! Map) return null;
    return CustomerInfo(
      name: (raw['name'] as String?) ?? '',
      phoneNumber: (raw['phoneNumber'] as String?) ?? '',
      email: raw['email'] as String?,
    );
  }

  static Map<String, dynamic> _customerInfoToMap(CustomerInfo c) {
    return {
      'name': c.name,
      'phoneNumber': c.phoneNumber,
      'email': c.email,
    };
  }

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
    return OrderItemEntity(
      id: (raw['id'] as String?) ?? '',
      productId: (raw['productId'] as String?) ?? '',
      productName: (raw['productName'] as String?) ?? '',
      productImageUrl: raw['productImageUrl'] as String?,
      quantity: (raw['quantity'] as int?) ?? 1,
      unitPrice: asDouble(raw['unitPrice']) ?? 0.0,
      totalPrice: asDouble(raw['totalPrice']) ?? 0.0,
      selectedSize: raw['selectedSize'] as String?,
      selectedOptions: asList<String>(raw['selectedOptions']),
      modifications: asList<String>(raw['modifications']),
      specialInstructions: raw['specialInstructions'] as String?,
    );
  }

  static Map<String, dynamic> _itemToMap(OrderItemEntity i) {
    return {
      'id': i.id,
      'productId': i.productId,
      'productName': i.productName,
      'productImageUrl': i.productImageUrl,
      'quantity': i.quantity,
      'unitPrice': i.unitPrice,
      'totalPrice': i.totalPrice,
      'selectedSize': i.selectedSize,
      'selectedOptions': i.selectedOptions,
      'modifications': i.modifications,
      'specialInstructions': i.specialInstructions,
    };
  }

  // ─── Enums helpers ───────────────────────────────────────────────────────
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
