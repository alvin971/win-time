import '../entities/category_entity.dart';
import '../entities/product_entity.dart';

/// Contrat read/write pour les sous-collections menu d'un restaurant :
/// `/restaurants/{rid}/categories/{cid}` et `/restaurants/{rid}/products/{pid}`.
abstract class MenuRepository {
  // ─── Categories ────────────────────────────────────────────────────────
  Stream<List<CategoryEntity>> watchCategories(String restaurantId);
  Future<List<CategoryEntity>> getCategories(String restaurantId);
  Future<CategoryEntity?> getCategoryById({
    required String restaurantId,
    required String categoryId,
  });
  Future<void> upsertCategory(CategoryEntity category);
  Future<void> deleteCategory({
    required String restaurantId,
    required String categoryId,
  });

  // ─── Products ──────────────────────────────────────────────────────────
  Stream<List<ProductEntity>> watchProducts(String restaurantId);
  Stream<List<ProductEntity>> watchProductsByCategory({
    required String restaurantId,
    required String categoryId,
  });
  Future<ProductEntity?> getProductById({
    required String restaurantId,
    required String productId,
  });
  Future<void> upsertProduct(ProductEntity product);
  Future<void> deleteProduct({
    required String restaurantId,
    required String productId,
  });

  /// Toggle disponibilité (utilisé par le Pro pour "rupture de stock"
  /// rapide sans ouvrir le formulaire complet).
  Future<void> setProductAvailable({
    required String restaurantId,
    required String productId,
    required bool isAvailable,
  });
}
