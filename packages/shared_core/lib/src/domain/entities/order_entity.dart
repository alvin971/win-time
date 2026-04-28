import 'package:equatable/equatable.dart';
import '../enums/order_status.dart';
import '../enums/payment_status.dart';
import '../enums/payment_method.dart';

/// Entité représentant une commande dans le système Win Time
class OrderEntity extends Equatable {
  /// Identifiant unique de la commande
  final String id;

  /// Numéro de commande affiché au client
  final String orderNumber;

  /// Identifiant du restaurant
  final String restaurantId;

  /// Identifiant du client
  final String customerId;

  /// Informations du client (pour l'app restaurant)
  final CustomerInfo? customerInfo;

  /// Liste des articles de la commande
  final List<OrderItemEntity> items;

  /// Montant total hors taxes
  final double subtotal;

  /// Montant des taxes
  final double taxAmount;

  /// Montant total TTC
  final double totalAmount;

  /// Commission de la plateforme (optionnel)
  final double? commissionAmount;

  /// Statut de la commande
  final OrderStatus status;

  /// Statut du paiement
  final PaymentStatus paymentStatus;

  /// Méthode de paiement utilisée
  final PaymentMethod paymentMethod;

  /// Date de création de la commande
  final DateTime createdAt;

  /// Date et heure prévues de retrait
  final DateTime? scheduledPickupTime;

  /// Date d'acceptation de la commande
  final DateTime? acceptedAt;

  /// Date où la commande est prête
  final DateTime? readyAt;

  /// Date de complétion de la commande
  final DateTime? completedAt;

  /// Date d'annulation de la commande
  final DateTime? cancelledAt;

  /// Temps de préparation estimé (en minutes)
  final int estimatedPreparationTime;

  /// Temps de préparation réel (en minutes, optionnel)
  final int? actualPreparationTime;

  /// Instructions spéciales du client
  final String? specialInstructions;

  /// Raison d'annulation (si applicable)
  final String? cancellationReason;

  /// Indique si la commande est payée
  final bool isPaid;

  /// Indique si la commande a été notée
  final bool isRated;

  /// Note donnée par le client (optionnel)
  final double? rating;

  /// Commentaire du client (optionnel)
  final String? review;

  /// Date de dernière mise à jour
  final DateTime updatedAt;

  const OrderEntity({
    required this.id,
    required this.orderNumber,
    required this.restaurantId,
    required this.customerId,
    this.customerInfo,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    this.commissionAmount,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.createdAt,
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
    required this.updatedAt,
  });

  /// Retourne le montant total formaté
  String get formattedTotal => '${totalAmount.toStringAsFixed(2)}€';

  /// Retourne le nombre total d'articles
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  /// Vérifie si la commande peut être annulée
  bool get canBeCancelled =>
      status == OrderStatus.pending || status == OrderStatus.accepted;

  /// Vérifie si la commande peut être acceptée (pour restaurant)
  bool get canBeAccepted => status == OrderStatus.pending;

  /// Vérifie si la commande peut être rejetée (pour restaurant)
  bool get canBeRejected =>
      status == OrderStatus.pending || status == OrderStatus.accepted;

  /// Vérifie si la commande peut être marquée prête (pour restaurant)
  bool get canBeMarkedReady => status == OrderStatus.preparing;

  /// Vérifie si la commande peut être complétée (pour restaurant)
  bool get canBeCompleted => status == OrderStatus.ready;

  /// Vérifie si la commande est active
  bool get isActive => status.isActive;

  /// Retourne la durée de préparation réelle (si disponible)
  Duration? get preparationDuration {
    if (acceptedAt != null && readyAt != null) {
      return readyAt!.difference(acceptedAt!);
    }
    return null;
  }

  /// Crée une copie de l'entité avec des valeurs modifiées
  OrderEntity copyWith({
    String? id,
    String? orderNumber,
    String? restaurantId,
    String? customerId,
    CustomerInfo? customerInfo,
    List<OrderItemEntity>? items,
    double? subtotal,
    double? taxAmount,
    double? totalAmount,
    double? commissionAmount,
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    PaymentMethod? paymentMethod,
    DateTime? createdAt,
    DateTime? scheduledPickupTime,
    DateTime? acceptedAt,
    DateTime? readyAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    int? estimatedPreparationTime,
    int? actualPreparationTime,
    String? specialInstructions,
    String? cancellationReason,
    bool? isPaid,
    bool? isRated,
    double? rating,
    String? review,
    DateTime? updatedAt,
  }) {
    return OrderEntity(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      restaurantId: restaurantId ?? this.restaurantId,
      customerId: customerId ?? this.customerId,
      customerInfo: customerInfo ?? this.customerInfo,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      scheduledPickupTime: scheduledPickupTime ?? this.scheduledPickupTime,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      readyAt: readyAt ?? this.readyAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      estimatedPreparationTime:
          estimatedPreparationTime ?? this.estimatedPreparationTime,
      actualPreparationTime:
          actualPreparationTime ?? this.actualPreparationTime,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      isPaid: isPaid ?? this.isPaid,
      isRated: isRated ?? this.isRated,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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
        commissionAmount,
        status,
        paymentStatus,
        paymentMethod,
        createdAt,
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
        updatedAt,
      ];
}

/// Entité représentant un article dans une commande
class OrderItemEntity extends Equatable {
  /// Identifiant unique de l'article
  final String id;

  /// Identifiant du produit
  final String productId;

  /// Nom du produit
  final String productName;

  /// URL de l'image du produit (optionnel)
  final String? productImageUrl;

  /// Quantité commandée
  final int quantity;

  /// Prix unitaire
  final double unitPrice;

  /// Prix total pour cet article
  final double totalPrice;

  /// Taille sélectionnée (optionnel)
  final String? selectedSize;

  /// Options sélectionnées
  final List<String> selectedOptions;

  /// Modifications demandées
  final List<String> modifications;

  /// Instructions spéciales pour cet article
  final String? specialInstructions;

  const OrderItemEntity({
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

  /// Retourne le prix unitaire formaté
  String get formattedUnitPrice => '${unitPrice.toStringAsFixed(2)}€';

  /// Retourne le prix total formaté
  String get formattedTotalPrice => '${totalPrice.toStringAsFixed(2)}€';

  /// Crée une copie de l'entité avec des valeurs modifiées
  OrderItemEntity copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productImageUrl,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    String? selectedSize,
    List<String>? selectedOptions,
    List<String>? modifications,
    String? specialInstructions,
  }) {
    return OrderItemEntity(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      selectedSize: selectedSize ?? this.selectedSize,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      modifications: modifications ?? this.modifications,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

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

/// Informations du client dans une commande (utilisé par l'app restaurant)
class CustomerInfo extends Equatable {
  /// Nom complet du client
  final String name;

  /// Numéro de téléphone du client
  final String phoneNumber;

  /// Email du client (optionnel)
  final String? email;

  const CustomerInfo({
    required this.name,
    required this.phoneNumber,
    this.email,
  });

  @override
  List<Object?> get props => [name, phoneNumber, email];
}
