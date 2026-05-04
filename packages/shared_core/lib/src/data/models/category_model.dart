import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/category_entity.dart';
import '_helpers.dart';

/// Mapper Firestore ↔ [CategoryEntity].
///
/// Stocké à `/restaurants/{rid}/categories/{cid}`.
class CategoryModel {
  static CategoryEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap, {
    String? restaurantIdOverride,
  }) {
    final data = snap.data() ?? const <String, dynamic>{};
    return CategoryEntity(
      id: snap.id,
      restaurantId: restaurantIdOverride ??
          (data['restaurantId'] as String?) ??
          _restaurantIdFromPath(snap.reference.path),
      name: (data['name'] as String?) ?? '',
      description: data['description'] as String?,
      iconUrl: data['iconUrl'] as String?,
      displayOrder: (data['displayOrder'] as int?) ?? 0,
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: ts(data['createdAt']) ?? DateTime.now(),
      updatedAt: ts(data['updatedAt']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> toFirestore(CategoryEntity c) {
    return {
      'restaurantId': c.restaurantId,
      'name': c.name,
      'description': c.description,
      'iconUrl': c.iconUrl,
      'displayOrder': c.displayOrder,
      'isActive': c.isActive,
      'createdAt': Timestamp.fromDate(c.createdAt),
      'updatedAt': Timestamp.fromDate(c.updatedAt),
    };
  }

  /// Extrait le `rid` du path Firestore `restaurants/{rid}/categories/{cid}`.
  static String _restaurantIdFromPath(String path) {
    final parts = path.split('/');
    final i = parts.indexOf('restaurants');
    return (i >= 0 && i + 1 < parts.length) ? parts[i + 1] : '';
  }
}
