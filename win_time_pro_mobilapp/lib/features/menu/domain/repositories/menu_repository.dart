import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/category_entity.dart';
import '../entities/product_entity.dart';

abstract class MenuRepository {
  Future<Either<Failure, List<CategoryEntity>>> getCategories({
    required String restaurantId,
  });

  Future<Either<Failure, CategoryEntity>> getCategoryById({
    required String categoryId,
  });

  Future<Either<Failure, CategoryEntity>> createCategory({
    required String restaurantId,
    required String name,
    String? description,
    String? iconUrl,
  });

  Future<Either<Failure, CategoryEntity>> updateCategory({
    required String categoryId,
    String? name,
    String? description,
    String? iconUrl,
    int? displayOrder,
    bool? isActive,
  });

  Future<Either<Failure, void>> deleteCategory({
    required String categoryId,
  });

  Future<Either<Failure, List<ProductEntity>>> getProducts({
    required String restaurantId,
    String? categoryId,
  });

  Future<Either<Failure, ProductEntity>> getProductById({
    required String productId,
  });

  Future<Either<Failure, ProductEntity>> createProduct({
    required String restaurantId,
    required String categoryId,
    required String name,
    required String description,
    required double price,
    String? mainImageUrl,
    List<String>? ingredients,
    int? estimatedPreparationTime,
  });

  Future<Either<Failure, ProductEntity>> updateProduct({
    required String productId,
    String? name,
    String? description,
    double? price,
    String? categoryId,
    String? mainImageUrl,
    List<String>? ingredients,
    bool? isAvailable,
    int? stockQuantity,
    int? estimatedPreparationTime,
  });

  Future<Either<Failure, void>> deleteProduct({
    required String productId,
  });

  Future<Either<Failure, ProductEntity>> toggleProductAvailability({
    required String productId,
  });

  Future<Either<Failure, List<CategoryEntity>>> reorderCategories({
    required List<String> categoryIds,
  });
}
