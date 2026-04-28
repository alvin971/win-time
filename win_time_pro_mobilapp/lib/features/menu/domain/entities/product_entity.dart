import 'package:equatable/equatable.dart';

class ProductEntity extends Equatable {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final String categoryId;

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
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
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

  bool get hasStock {
    if (stockQuantity == null) return true;
    return stockQuantity! > 0;
  }

  bool get isCurrentlyAvailable {
    if (!isAvailable || !hasStock) return false;
    if (!isSeasonal) return true;

    final now = DateTime.now();
    if (availableFrom != null && now.isBefore(availableFrom!)) return false;
    if (availableUntil != null && now.isAfter(availableUntil!)) return false;

    return true;
  }

  @override
  List<Object?> get props => [
        id,
        restaurantId,
        name,
        description,
        price,
        categoryId,
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
  List<Object?> get props => [id, name, additionalPrice, isAvailable, maxQuantity];
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
  List<Object?> get props => [
        calories,
        proteins,
        carbohydrates,
        fats,
        fiber,
        sugar,
        salt,
      ];
}

enum Allergen {
  gluten,
  crustaceans,
  eggs,
  fish,
  peanuts,
  soy,
  milk,
  nuts,
  celery,
  mustard,
  sesame,
  sulfites,
  lupin,
  molluscs,
}

enum ProductLabel {
  bio,
  vegan,
  vegetarian,
  glutenFree,
  lactoseFree,
  homemade,
  spicy,
  new_,
  bestseller,
  chefRecommendation,
}
