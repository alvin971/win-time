import 'dart:typed_data';

import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/wintime_supabase_config.dart';

/// Datasource Menu côté Pro (CRUD complet catégories + produits + photos).
///
/// Tables : `wintime.categories` et `wintime.products`.
/// Storage : photos produits dans bucket `restaurant-photos` sous
/// `{ownerUid}/products/{productId}.jpg` (RLS exige owner-only).
class SupabaseMenuDataSource {
  final SupabaseClient _client;
  SupabaseMenuDataSource(this._client);

  PostgrestQueryBuilder get _categories =>
      _client.schema(WintimeSupabaseConfig.schema).from('categories');

  PostgrestQueryBuilder get _products =>
      _client.schema(WintimeSupabaseConfig.schema).from('products');

  // ─── Reads ─────────────────────────────────────────────────────────────

  Future<List<CategoryEntity>> getCategories(String restaurantId) async {
    final rows = await _categories
        .select()
        .eq('restaurant_id', restaurantId)
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

  // ─── Categories CRUD ───────────────────────────────────────────────────

  Future<String> createCategory(CategoryEntity c) async {
    final row = CategoryModel.toRow(c);
    row.remove('id'); // Postgres génère
    final result = await _categories.insert(row).select('id').single();
    return result['id'] as String;
  }

  Future<void> updateCategory(CategoryEntity c) async {
    final row = CategoryModel.toRow(c);
    row.remove('id');
    await _categories.update(row).eq('id', c.id);
  }

  Future<void> deleteCategory(String categoryId) async {
    // Cascade : Postgres `ON DELETE CASCADE` supprime aussi les produits
    // de cette catégorie (cf. migration 010).
    await _categories.delete().eq('id', categoryId);
  }

  // ─── Products CRUD ─────────────────────────────────────────────────────

  Future<String> createProduct(ProductEntity p) async {
    final row = ProductModel.toRow(p);
    row.remove('id');
    final result = await _products.insert(row).select('id').single();
    return result['id'] as String;
  }

  Future<void> updateProduct(ProductEntity p) async {
    final row = ProductModel.toRow(p);
    row.remove('id');
    await _products.update(row).eq('id', p.id);
  }

  Future<void> deleteProduct(String productId) async {
    await _products.delete().eq('id', productId);
  }

  Future<void> setProductAvailable(String productId, bool isAvailable) async {
    await _products.update({'is_available': isAvailable}).eq('id', productId);
  }

  // ─── Storage : photo produit ──────────────────────────────────────────

  /// Upload une photo de produit dans `restaurant-photos/{ownerUid}/products/{productId}.jpg`.
  /// Retourne l'URL publique.
  Future<String> uploadProductPhoto({
    required String ownerUid,
    required String productId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    const bucket = 'restaurant-photos';
    final path = '$ownerUid/products/$productId.jpg';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
            cacheControl: '3600',
          ),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }
}

/// Bundle de retour pour [SupabaseMenuDataSource.getMenuBundle].
class MenuBundle {
  final List<CategoryEntity> categories;
  final Map<String, List<ProductEntity>> productsByCategory;
  const MenuBundle({
    required this.categories,
    required this.productsByCategory,
  });
}
