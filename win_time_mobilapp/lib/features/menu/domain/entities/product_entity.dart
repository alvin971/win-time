import 'package:equatable/equatable.dart';

class ProductEntity extends Equatable {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final String category;
  final String? photoUrl;
  final bool isAvailable;
  final int preparationTimeEstimate; // en minutes
  final List<String> allergens;
  final Map<String, dynamic>? nutritionalInfo;
  final List<ProductOption> options;

  const ProductEntity({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.photoUrl,
    required this.isAvailable,
    required this.preparationTimeEstimate,
    required this.allergens,
    this.nutritionalInfo,
    required this.options,
  });

  String get formattedPrice => '${price.toStringAsFixed(2)}€';

  bool get hasAllergens => allergens.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        restaurantId,
        name,
        description,
        price,
        category,
        photoUrl,
        isAvailable,
        preparationTimeEstimate,
        allergens,
        nutritionalInfo,
        options,
      ];
}

class ProductOption extends Equatable {
  final String id;
  final String name;
  final List<ProductOptionValue> values;
  final bool isRequired;
  final bool isMultiple;

  const ProductOption({
    required this.id,
    required this.name,
    required this.values,
    required this.isRequired,
    required this.isMultiple,
  });

  @override
  List<Object?> get props => [id, name, values, isRequired, isMultiple];
}

class ProductOptionValue extends Equatable {
  final String id;
  final String name;
  final double priceModifier;

  const ProductOptionValue({
    required this.id,
    required this.name,
    required this.priceModifier,
  });

  @override
  List<Object?> get props => [id, name, priceModifier];
}
