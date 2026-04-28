import 'package:equatable/equatable.dart';

enum OrderStatus {
  pending,
  accepted,
  preparing,
  ready,
  completed,
  cancelled,
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
}

class OrderEntity extends Equatable {
  final String id;
  final String orderNumber;
  final String customerId;
  final String restaurantId;
  final OrderStatus status;
  final double totalAmount;
  final double commissionAmount;
  final PaymentStatus paymentStatus;
  final String paymentMethod;
  final int estimatedPreparationTime; // en minutes
  final int? actualPreparationTime; // en minutes
  final DateTime scheduledPickupTime;
  final DateTime? actualPickupTime;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final String? specialInstructions;
  final String? cancellationReason;
  final List<OrderItemEntity> items;

  const OrderEntity({
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

  String get formattedTotal => '${totalAmount.toStringAsFixed(2)}€';

  bool get canBeCancelled =>
      status == OrderStatus.pending || status == OrderStatus.accepted;

  bool get isPending => status == OrderStatus.pending;
  bool get isAccepted => status == OrderStatus.accepted;
  bool get isPreparing => status == OrderStatus.preparing;
  bool get isReady => status == OrderStatus.ready;
  bool get isCompleted => status == OrderStatus.completed;
  bool get isCancelled => status == OrderStatus.cancelled;

  String get statusDisplay {
    switch (status) {
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.accepted:
        return 'Acceptée';
      case OrderStatus.preparing:
        return 'En préparation';
      case OrderStatus.ready:
        return 'Prête';
      case OrderStatus.completed:
        return 'Terminée';
      case OrderStatus.cancelled:
        return 'Annulée';
    }
  }

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  @override
  List<Object?> get props => [
        id,
        orderNumber,
        customerId,
        restaurantId,
        status,
        totalAmount,
        commissionAmount,
        paymentStatus,
        paymentMethod,
        estimatedPreparationTime,
        actualPreparationTime,
        scheduledPickupTime,
        actualPickupTime,
        createdAt,
        acceptedAt,
        readyAt,
        completedAt,
        specialInstructions,
        cancellationReason,
        items,
      ];
}

class OrderItemEntity extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final Map<String, dynamic>? optionsSelected;
  final String? specialNotes;

  const OrderItemEntity({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.optionsSelected,
    this.specialNotes,
  });

  String get formattedUnitPrice => '${unitPrice.toStringAsFixed(2)}€';
  String get formattedTotalPrice => '${totalPrice.toStringAsFixed(2)}€';

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        quantity,
        unitPrice,
        totalPrice,
        optionsSelected,
        specialNotes,
      ];
}
