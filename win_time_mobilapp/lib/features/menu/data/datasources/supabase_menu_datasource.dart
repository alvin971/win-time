import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/wintime_supabase_config.dart';

/// Lecture du menu (catégories + produits) d'un restaurant.
class SupabaseMenuDataSource {
  final SupabaseClient _client;
  SupabaseMenuDataSource(this._client);

  PostgrestQueryBuilder get _categories =>
      _client.schema(WintimeSupabaseConfig.schema).from('categories');

  PostgrestQueryBuilder get _products =>
      _client.schema(WintimeSupabaseConfig.schema).from('products');

  Future<List<CategoryEntity>> getCategories(String restaurantId) async {
    final rows = await _categories
        .select()
        .eq('restaurant_id', restaurantId)
        .eq('is_active', true)
        .order('display_order', ascending: true);
    return (rows as List<dynamic>)
        .map((r) => CategoryModel.fromRow((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<ProductEntity>> getProducts(String restaurantId) async {
    final rows = await _products
        .select()
        .eq('restaurant_id', restaurantId)
        .order('name', ascending: true);
    return (rows as List<dynamic>)
        .map((r) => ProductModel.fromRow((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Convenience : récupère catégories + produits en parallèle pour la page
  /// détail. Retourne un map `{categoryId: List<ProductEntity>}` plus
  /// commode pour le rendu sectionné.
  Future<MenuBundle> getMenuBundle(String restaurantId) async {
    final results = await Future.wait([
      getCategories(restaurantId),
      getProducts(restaurantId),
    ]);
    final cats = results[0] as List<CategoryEntity>;
    final prods = results[1] as List<ProductEntity>;
    final byCategory = <String, List<ProductEntity>>{};
    for (final p in prods) {
      byCategory.putIfAbsent(p.categoryId, () => []).add(p);
    }
    return MenuBundle(categories: cats, productsByCategory: byCategory);
  }
}

class MenuBundle {
  final List<CategoryEntity> categories;
  final Map<String, List<ProductEntity>> productsByCategory;
  const MenuBundle({required this.categories, required this.productsByCategory});
}
