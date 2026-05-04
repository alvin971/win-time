import '../../domain/entities/product_entity.dart';
import '../../domain/enums/allergen.dart';
import '../../domain/enums/product_label.dart';
import '_helpers.dart';

/// Mapper Postgres ↔ [ProductEntity].
/// Table : `wintime.products`. Colonnes JSONB pour `sizes`/`options`/
/// `nutritional_info`, `text[]` pour `ingredients`/`allergens`/`labels`.
class ProductModel {
  static ProductEntity fromRow(Map<String, dynamic> row) {
    return ProductEntity(
      id: row['id'] as String,
      restaurantId: (row['restaurant_id'] as String?) ?? '',
      categoryId: (row['category_id'] as String?) ?? '',
      name: (row['name'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      price: asDouble(row['price']) ?? 0.0,
      mainImageUrl: row['main_image_url'] as String?,
      additionalImages: asList<String>(row['additional_images']),
      ingredients: asList<String>(row['ingredients']),
      allergens: asList<String>(row['allergens'])
          .map(AllergenX.fromString)
          .toList(),
      nutritionalInfo: _nutritionalInfoFromMap(row['nutritional_info']),
      labels: asList<String>(row['labels'])
          .map(ProductLabelX.fromString)
          .toList(),
      sizes: asList<dynamic>(row['sizes']).map(_sizeFromMap).toList(),
      options: asList<dynamic>(row['options']).map(_optionFromMap).toList(),
      allowedModifications: asList<String>(row['allowed_modifications']),
      isAvailable: (row['is_available'] as bool?) ?? true,
      stockQuantity: asInt(row['stock_quantity']),
      estimatedPreparationTime: asInt(row['estimated_preparation_time']) ?? 15,
      isSeasonal: (row['is_seasonal'] as bool?) ?? false,
      availableFrom: ts(row['available_from']),
      availableUntil: ts(row['available_until']),
      orderCount: asInt(row['order_count']) ?? 0,
      rating: asDouble(row['rating']),
      createdAt: ts(row['created_at']) ?? DateTime.now(),
      updatedAt: ts(row['updated_at']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> toRow(ProductEntity p) {
    return {
      if (p.id.isNotEmpty) 'id': p.id,
      'restaurant_id': p.restaurantId,
      'category_id': p.categoryId,
      'name': p.name,
      'description': p.description,
      'price': p.price,
      'main_image_url': p.mainImageUrl,
      'additional_images': p.additionalImages,
      'ingredients': p.ingredients,
      'allergens': p.allergens.map((e) => e.name).toList(),
      'nutritional_info': _nutritionalInfoToMap(p.nutritionalInfo),
      'labels': p.labels.map((e) => e.name).toList(),
      'sizes': p.sizes.map(_sizeToMap).toList(),
      'options': p.options.map(_optionToMap).toList(),
      'allowed_modifications': p.allowedModifications,
      'is_available': p.isAvailable,
      'stock_quantity': p.stockQuantity,
      'estimated_preparation_time': p.estimatedPreparationTime,
      'is_seasonal': p.isSeasonal,
      'available_from': tsString(p.availableFrom),
      'available_until': tsString(p.availableUntil),
      'rating': p.rating,
    };
  }

  static ProductSize _sizeFromMap(dynamic raw) {
    if (raw is! Map) {
      return const ProductSize(id: '', name: '', priceModifier: 0);
    }
    return ProductSize(
      id: (raw['id'] as String?) ?? '',
      name: (raw['name'] as String?) ?? '',
      priceModifier: asDouble(raw['priceModifier']) ?? 0.0,
      isDefault: (raw['isDefault'] as bool?) ?? false,
    );
  }

  static Map<String, dynamic> _sizeToMap(ProductSize s) => {
        'id': s.id,
        'name': s.name,
        'priceModifier': s.priceModifier,
        'isDefault': s.isDefault,
      };

  static ProductOption _optionFromMap(dynamic raw) {
    if (raw is! Map) {
      return const ProductOption(id: '', name: '', additionalPrice: 0);
    }
    return ProductOption(
      id: (raw['id'] as String?) ?? '',
      name: (raw['name'] as String?) ?? '',
      additionalPrice: asDouble(raw['additionalPrice']) ?? 0.0,
      isAvailable: (raw['isAvailable'] as bool?) ?? true,
      maxQuantity: asInt(raw['maxQuantity']),
    );
  }

  static Map<String, dynamic> _optionToMap(ProductOption o) => {
        'id': o.id,
        'name': o.name,
        'additionalPrice': o.additionalPrice,
        'isAvailable': o.isAvailable,
        'maxQuantity': o.maxQuantity,
      };

  static NutritionalInfo? _nutritionalInfoFromMap(dynamic raw) {
    if (raw is! Map) return null;
    return NutritionalInfo(
      calories: asDouble(raw['calories']),
      proteins: asDouble(raw['proteins']),
      carbohydrates: asDouble(raw['carbohydrates']),
      fats: asDouble(raw['fats']),
      fiber: asDouble(raw['fiber']),
      sugar: asDouble(raw['sugar']),
      salt: asDouble(raw['salt']),
    );
  }

  static Map<String, dynamic>? _nutritionalInfoToMap(NutritionalInfo? n) {
    if (n == null) return null;
    return {
      'calories': n.calories,
      'proteins': n.proteins,
      'carbohydrates': n.carbohydrates,
      'fats': n.fats,
      'fiber': n.fiber,
      'sugar': n.sugar,
      'salt': n.salt,
    };
  }
}
