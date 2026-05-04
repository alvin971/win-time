import '../../domain/entities/category_entity.dart';
import '_helpers.dart';

/// Mapper Postgres ↔ [CategoryEntity].
/// Table : `wintime.categories`.
class CategoryModel {
  static CategoryEntity fromRow(Map<String, dynamic> row) {
    return CategoryEntity(
      id: row['id'] as String,
      restaurantId: (row['restaurant_id'] as String?) ?? '',
      name: (row['name'] as String?) ?? '',
      description: row['description'] as String?,
      iconUrl: row['icon_url'] as String?,
      displayOrder: asInt(row['display_order']) ?? 0,
      isActive: (row['is_active'] as bool?) ?? true,
      createdAt: ts(row['created_at']) ?? DateTime.now(),
      updatedAt: ts(row['updated_at']) ?? DateTime.now(),
    );
  }

  /// Sérialise pour insert/update. `id` inclus seulement si non-vide
  /// (sinon Postgres génère via `gen_random_uuid()`).
  static Map<String, dynamic> toRow(CategoryEntity c) {
    return {
      if (c.id.isNotEmpty) 'id': c.id,
      'restaurant_id': c.restaurantId,
      'name': c.name,
      'description': c.description,
      'icon_url': c.iconUrl,
      'display_order': c.displayOrder,
      'is_active': c.isActive,
    };
  }
}
