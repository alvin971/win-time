import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';

import '../../../../core/di/injection_container.dart';
import '../../data/datasources/supabase_menu_datasource.dart';
import '../widgets/category_edit_sheet.dart';
import 'product_form_page.dart';

/// Page principale Menu (côté commerçant).
///
/// Liste les catégories du restaurant courant. Pour chaque catégorie, liste
/// ses produits (collapsible). Permet d'ajouter / modifier / supprimer une
/// catégorie ou un produit, et d'uploader une photo par produit.
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  late final SupabaseMenuDataSource _ds;
  bool _loading = true;
  String? _error;
  MenuBundle _bundle = const MenuBundle(categories: [], productsByCategory: {});
  String? _restaurantId;

  @override
  void initState() {
    super.initState();
    _ds = ServiceLocator.menuDataSource;
    _restaurantId = ServiceLocator.currentRestaurantId;
    _refresh();
  }

  Future<void> _refresh() async {
    final rid = _restaurantId;
    if (rid == null) {
      setState(() {
        _loading = false;
        _error = 'Aucun restaurant associé. Crée ton restaurant d\'abord.';
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final bundle = await _ds.getMenuBundle(rid);
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erreur chargement : $e';
      });
    }
  }

  Future<void> _addCategory() async {
    final rid = _restaurantId;
    if (rid == null) return;
    final created = await showCategoryEditSheet(
      context: context,
      restaurantId: rid,
      existing: null,
      dataSource: _ds,
    );
    if (created == true) await _refresh();
  }

  Future<void> _editCategory(CategoryEntity c) async {
    final rid = _restaurantId;
    if (rid == null) return;
    final changed = await showCategoryEditSheet(
      context: context,
      restaurantId: rid,
      existing: c,
      dataSource: _ds,
    );
    if (changed == true) await _refresh();
  }

  Future<void> _addProduct(String categoryId) async {
    final rid = _restaurantId;
    if (rid == null) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormPage(
          restaurantId: rid,
          categoryId: categoryId,
          existingProductId: null,
        ),
      ),
    );
    if (created == true) await _refresh();
  }

  Future<void> _editProduct(ProductEntity p) async {
    final rid = _restaurantId;
    if (rid == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormPage(
          restaurantId: rid,
          categoryId: p.categoryId,
          existingProductId: p.id,
        ),
      ),
    );
    if (changed == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: _restaurantId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addCategory,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une catégorie'),
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_bundle.categories.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('Aucune catégorie',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'Crée ta première catégorie pour commencer\n'
                      '(ex: Entrées, Plats, Desserts).',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _addCategory,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une catégorie'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (final cat in _bundle.categories)
            _CategorySection(
              category: cat,
              products: _bundle.productsByCategory[cat.id] ?? const [],
              onEditCategory: () => _editCategory(cat),
              onAddProduct: () => _addProduct(cat.id),
              onEditProduct: _editProduct,
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final CategoryEntity category;
  final List<ProductEntity> products;
  final VoidCallback onEditCategory;
  final VoidCallback onAddProduct;
  final ValueChanged<ProductEntity> onEditProduct;

  const _CategorySection({
    required this.category,
    required this.products,
    required this.onEditCategory,
    required this.onAddProduct,
    required this.onEditProduct,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            tileColor: Colors.amber.shade50,
            leading: const Icon(Icons.category, color: Colors.amber),
            title: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${products.length} produit${products.length > 1 ? "s" : ""}'
              '${category.isActive ? "" : " · Inactive"}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEditCategory,
              tooltip: 'Modifier la catégorie',
            ),
          ),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Aucun produit dans cette catégorie.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onAddProduct,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un produit'),
                  ),
                ],
              ),
            )
          else ...[
            for (final p in products)
              _ProductTile(product: p, onEdit: () => onEditProduct(p)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextButton.icon(
                onPressed: onAddProduct,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un produit'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ProductEntity product;
  final VoidCallback onEdit;
  const _ProductTile({required this.product, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = (product.mainImageUrl ?? '').isNotEmpty;
    return ListTile(
      onTap: onEdit,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 48,
          height: 48,
          child: hasPhoto
              ? CachedNetworkImage(
                  imageUrl: product.mainImageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
      title: Text(
        product.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: product.isAvailable ? Colors.black87 : Colors.grey,
          decoration:
              product.isAvailable ? null : TextDecoration.lineThrough,
        ),
      ),
      subtitle: Text(
        product.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            product.formattedPrice,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (!product.isAvailable)
            const Text('Indisponible',
                style: TextStyle(fontSize: 10, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.fastfood, color: Colors.grey),
      );
}
