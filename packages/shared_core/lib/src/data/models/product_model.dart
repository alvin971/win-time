import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/product_entity.dart';
import '../../domain/enums/allergen.dart';
import '../../domain/enums/product_label.dart';
import '_helpers.dart';

/// Mapper Firestore ↔ [ProductEntity].
///
/// Stocké à `/restaurants/{rid}/products/{pid}`.
class ProductModel {
  static ProductEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap, {
    String? restaurantIdOverride,
  }) {
    final data = snap.data() ?? const <String, dynamic>{};
    return ProductEntity(
      id: snap.id,
      restaurantId: restaurantIdOverride ??
          (data['restaurantId'] as String?) ??
          _restaurantIdFromPath(snap.reference.path),
      categoryId: (data['categoryId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      price: asDouble(data['price']) ?? 0.0,
      mainImageUrl: data['mainImageUrl'] as String?,
      additionalImages: asList<String>(data['additionalImages']),
      ingredients: asList<String>(data['ingredients']),
      allergens: asList<String>(data['allergens'])
          .map((e) => AllergenX.fromString(e))
          .toList(),
      nutritionalInfo: _nutritionalInfoFromMap(data['nutritionalInfo']),
      labels: asList<String>(data['labels'])
          .map((e) => ProductLabelX.fromString(e))
          .toList(),
      sizes: asList<dynamic>(data['sizes']).map(_sizeFromMap).toList(),
      options: asList<dynamic>(data['options']).map(_optionFromMap).toList(),
      allowedModifications: asList<String>(data['allowedModifications']),
      isAvailable: (data['isAvailable'] as bool?) ?? true,
      stockQuantity: data['stockQuantity'] as int?,
      estimatedPreparationTime:
          (data['estimatedPreparationTime'] as int?) ?? 15,
      isSeasonal: (data['isSeasonal'] as bool?) ?? false,
      availableFrom: ts(data['availableFrom']),
      availableUntil: ts(data['availableUntil']),
      orderCount: (data['orderCount'] as int?) ?? 0,
      rating: asDouble(data['rating']),
      createdAt: ts(data['createdAt']) ?? DateTime.now(),
      updatedAt: ts(data['updatedAt']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> toFirestore(ProductEntity p) {
    return {
      'restaurantId': p.restaurantId,
      'categoryId': p.categoryId,
      'name': p.name,
      'description': p.description,
      'price': p.price,
      'mainImageUrl': p.mainImageUrl,
      'additionalImages': p.additionalImages,
      'ingredients': p.ingredients,
      'allergens': p.allergens.map((e) => e.name).toList(),
      'nutritionalInfo': _nutritionalInfoToMap(p.nutritionalInfo),
      'labels': p.labels.map((e) => e.name).toList(),
      'sizes': p.sizes.map(_sizeToMap).toList(),
      'options': p.options.map(_optionToMap).toList(),
      'allowedModifications': p.allowedModifications,
      'isAvailable': p.isAvailable,
      'stockQuantity': p.stockQuantity,
      'estimatedPreparationTime': p.estimatedPreparationTime,
      'isSeasonal': p.isSeasonal,
      'availableFrom':
          p.availableFrom != null ? Timestamp.fromDate(p.availableFrom!) : null,
      'availableUntil': p.availableUntil != null
          ? Timestamp.fromDate(p.availableUntil!)
          : null,
      'orderCount': p.orderCount,
      'rating': p.rating,
      'createdAt': Timestamp.fromDate(p.createdAt),
      'updatedAt': Timestamp.fromDate(p.updatedAt),
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

  static Map<String, dynamic> _sizeToMap(ProductSize s) {
    return {
      'id': s.id,
      'name': s.name,
      'priceModifier': s.priceModifier,
      'isDefault': s.isDefault,
    };
  }

  static ProductOption _optionFromMap(dynamic raw) {
    if (raw is! Map) {
      return const ProductOption(id: '', name: '', additionalPrice: 0);
    }
    return ProductOption(
      id: (raw['id'] as String?) ?? '',
      name: (raw['name'] as String?) ?? '',
      additionalPrice: asDouble(raw['additionalPrice']) ?? 0.0,
      isAvailable: (raw['isAvailable'] as bool?) ?? true,
      maxQuantity: raw['maxQuantity'] as int?,
    );
  }

  static Map<String, dynamic> _optionToMap(ProductOption o) {
    return {
      'id': o.id,
      'name': o.name,
      'additionalPrice': o.additionalPrice,
      'isAvailable': o.isAvailable,
      'maxQuantity': o.maxQuantity,
    };
  }

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

  static String _restaurantIdFromPath(String path) {
    final parts = path.split('/');
    final i = parts.indexOf('restaurants');
    return (i >= 0 && i + 1 < parts.length) ? parts[i + 1] : '';
  }
}
