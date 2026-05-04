import 'package:equatable/equatable.dart';

import '../enums/allergen.dart';
import '../enums/product_label.dart';

class ProductSize extends Equatable {
  final String id;
  final String name;
  final double priceModifier;
  final bool isDefault;

  const ProductSize({
    required this.id,
    required this.name,
    required this.priceModifier,
    this.isDefault = false,
  });

  @override
  List<Object?> get props => [id, name, priceModifier, isDefault];
}

class ProductOption extends Equatable {
  final String id;
  final String name;
  final double additionalPrice;
  final bool isAvailable;
  final int? maxQuantity;

  const ProductOption({
    required this.id,
    required this.name,
    required this.additionalPrice,
    this.isAvailable = true,
    this.maxQuantity,
  });

  @override
  List<Object?> get props =>
      [id, name, additionalPrice, isAvailable, maxQuantity];
}

class NutritionalInfo extends Equatable {
  final double? calories;
  final double? proteins;
  final double? carbohydrates;
  final double? fats;
  final double? fiber;
  final double? sugar;
  final double? salt;

  const NutritionalInfo({
    this.calories,
    this.proteins,
    this.carbohydrates,
    this.fats,
    this.fiber,
    this.sugar,
    this.salt,
  });

  @override
  List<Object?> get props =>
      [calories, proteins, carbohydrates, fats, fiber, sugar, salt];
}

class ProductEntity extends Equatable {
  final String id;
  final String restaurantId;
  final String categoryId;

  final String name;
  final String description;
  final double price;

  final String? mainImageUrl;
  final List<String> additionalImages;

  final List<String> ingredients;
  final List<Allergen> allergens;
  final NutritionalInfo? nutritionalInfo;
  final List<ProductLabel> labels;

  final List<ProductSize> sizes;
  final List<ProductOption> options;
  final List<String> allowedModifications;

  final bool isAvailable;
  final int? stockQuantity;
  final int estimatedPreparationTime;

  final bool isSeasonal;
  final DateTime? availableFrom;
  final DateTime? availableUntil;

  final int orderCount;
  final double? rating;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductEntity({
    required this.id,
    required this.restaurantId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    this.mainImageUrl,
    this.additionalImages = const [],
    this.ingredients = const [],
    this.allergens = const [],
    this.nutritionalInfo,
    this.labels = const [],
    this.sizes = const [],
    this.options = const [],
    this.allowedModifications = const [],
    this.isAvailable = true,
    this.stockQuantity,
    this.estimatedPreparationTime = 15,
    this.isSeasonal = false,
    this.availableFrom,
    this.availableUntil,
    this.orderCount = 0,
    this.rating,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasStock => stockQuantity == null || stockQuantity! > 0;

  bool get isCurrentlyAvailable {
    if (!isAvailable || !hasStock) return false;
    if (!isSeasonal) return true;
    final now = DateTime.now();
    if (availableFrom != null && now.isBefore(availableFrom!)) return false;
    if (availableUntil != null && now.isAfter(availableUntil!)) return false;
    return true;
  }

  String get formattedPrice => '${price.toStringAsFixed(2)} €';

  ProductEntity copyWith({
    String? id,
    String? restaurantId,
    String? categoryId,
    String? name,
    String? description,
    double? price,
    String? mainImageUrl,
    List<String>? additionalImages,
    List<String>? ingredients,
    List<Allergen>? allergens,
    NutritionalInfo? nutritionalInfo,
    List<ProductLabel>? labels,
    List<ProductSize>? sizes,
    List<ProductOption>? options,
    List<String>? allowedModifications,
    bool? isAvailable,
    int? stockQuantity,
    int? estimatedPreparationTime,
    bool? isSeasonal,
    DateTime? availableFrom,
    DateTime? availableUntil,
    int? orderCount,
    double? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductEntity(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      mainImageUrl: mainImageUrl ?? this.mainImageUrl,
      additionalImages: additionalImages ?? this.additionalImages,
      ingredients: ingredients ?? this.ingredients,
      allergens: allergens ?? this.allergens,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
      labels: labels ?? this.labels,
      sizes: sizes ?? this.sizes,
      options: options ?? this.options,
      allowedModifications: allowedModifications ?? this.allowedModifications,
      isAvailable: isAvailable ?? this.isAvailable,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      estimatedPreparationTime:
          estimatedPreparationTime ?? this.estimatedPreparationTime,
      isSeasonal: isSeasonal ?? this.isSeasonal,
      availableFrom: availableFrom ?? this.availableFrom,
      availableUntil: availableUntil ?? this.availableUntil,
      orderCount: orderCount ?? this.orderCount,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        restaurantId,
        categoryId,
        name,
        description,
        price,
        mainImageUrl,
        additionalImages,
        ingredients,
        allergens,
        nutritionalInfo,
        labels,
        sizes,
        options,
        allowedModifications,
        isAvailable,
        stockQuantity,
        estimatedPreparationTime,
        isSeasonal,
        availableFrom,
        availableUntil,
        orderCount,
        rating,
        createdAt,
        updatedAt,
      ];
}
