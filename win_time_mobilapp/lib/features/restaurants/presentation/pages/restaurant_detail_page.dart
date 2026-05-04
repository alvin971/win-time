import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../cart/presentation/bloc/cart_bloc.dart';
import '../../../menu/data/datasources/supabase_menu_datasource.dart';
import '../../data/datasources/supabase_restaurants_datasource.dart';

/// Page détail d'un restaurant : header (nom, photo, infos) + menu sectionné
/// par catégorie. Tap sur un produit → bottom sheet pour ajout au cart.
class RestaurantDetailPage extends StatefulWidget {
  final String restaurantId;
  const RestaurantDetailPage({super.key, required this.restaurantId});

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  late final SupabaseRestaurantsDataSource _restosDs;
  late final SupabaseMenuDataSource _menuDs;
  Future<({RestaurantEntity? restaurant, MenuBundle menu})>? _future;

  @override
  void initState() {
    super.initState();
    _restosDs = SupabaseRestaurantsDataSource(Supabase.instance.client);
    _menuDs = SupabaseMenuDataSource(Supabase.instance.client);
    _future = _load();
  }

  Future<({RestaurantEntity? restaurant, MenuBundle menu})> _load() async {
    final results = await Future.wait([
      _restosDs.getById(widget.restaurantId),
      _menuDs.getMenuBundle(widget.restaurantId),
    ]);
    return (
      restaurant: results[0] as RestaurantEntity?,
      menu: results[1] as MenuBundle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }
          final data = snap.data!;
          final r = data.restaurant;
          if (r == null) {
            return const Center(child: Text('Restaurant introuvable.'));
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                title: Text(r.name),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: Colors.orange.shade100,
                    child: const Center(
                      child: Icon(Icons.restaurant, size: 80, color: Colors.orange),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _RestaurantHeader(restaurant: r),
                    const SizedBox(height: 24),
                    ..._buildMenu(data.menu, r.id),
                    const SizedBox(height: 100), // espace pour le bouton flottant
                  ]),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: BlocBuilder<CartBloc, CartState>(
        builder: (context, cartState) {
          if (cartState.isEmpty || cartState.restaurantId != widget.restaurantId) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => context.push('/checkout'),
            icon: const Icon(Icons.shopping_cart),
            label: Text(
              'Voir panier (${cartState.itemCount}) — '
              '${cartState.subtotal.toStringAsFixed(2)} €',
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildMenu(MenuBundle menu, String restaurantId) {
    if (menu.categories.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('Aucune catégorie au menu pour le moment.')),
        ),
      ];
    }
    final widgets = <Widget>[];
    for (final cat in menu.categories) {
      final products = menu.productsByCategory[cat.id] ?? const [];
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          cat.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ));
      for (final p in products) {
        widgets.add(_ProductTile(
          product: p,
          restaurantId: restaurantId,
        ));
      }
    }
    return widgets;
  }
}

class _RestaurantHeader extends StatelessWidget {
  final RestaurantEntity restaurant;
  const _RestaurantHeader({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (restaurant.slogan != null) ...[
          Text(
            restaurant.slogan!,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 8),
        ],
        if (restaurant.description != null) ...[
          Text(restaurant.description!),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            const Icon(Icons.local_dining, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(restaurant.cuisineType.displayName),
            const SizedBox(width: 16),
            Text(
              restaurant.priceRange.symbol,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            if (restaurant.rating != null) ...[
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text('${restaurant.rating!.toStringAsFixed(1)} '
                  '(${restaurant.totalReviews} avis)'),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(child: Text(restaurant.address.fullAddress)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              restaurant.isOpenForOrders ? Icons.check_circle : Icons.cancel,
              size: 16,
              color: restaurant.isOpenForOrders ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 4),
            Text(restaurant.isOpenForOrders
                ? 'Ouvert — accepte les commandes'
                : 'Fermé / n\'accepte plus de commandes'),
          ],
        ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ProductEntity product;
  final String restaurantId;
  const _ProductTile({required this.product, required this.restaurantId});

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => _ProductBottomSheet(
        product: product,
        restaurantId: restaurantId,
        cartBloc: context.read<CartBloc>(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          product.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              product.formattedPrice,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.add_circle, color: Colors.orange),
          ],
        ),
        onTap: () => _showAddSheet(context),
      ),
    );
  }
}

class _ProductBottomSheet extends StatefulWidget {
  final ProductEntity product;
  final String restaurantId;
  final CartBloc cartBloc;
  const _ProductBottomSheet({
    required this.product,
    required this.restaurantId,
    required this.cartBloc,
  });

  @override
  State<_ProductBottomSheet> createState() => _ProductBottomSheetState();
}

class _ProductBottomSheetState extends State<_ProductBottomSheet> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 4),
          Text(p.formattedPrice,
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              )),
          const SizedBox(height: 12),
          Text(p.description),
          if (p.allergens.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Allergènes',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in p.allergens)
                  Chip(
                    label: Text(a.displayName, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.red.shade50,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (p.labels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final l in p.labels)
                  Chip(
                    label: Text(l.displayName, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.green.shade50,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              IconButton(
                onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_quantity',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add_circle_outline),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _addToCart(context),
                icon: const Icon(Icons.shopping_cart),
                label: Text(
                  'Ajouter — ${(p.price * _quantity).toStringAsFixed(2)} €',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addToCart(BuildContext context) {
    final cart = widget.cartBloc;
    final state = cart.state;
    if (state.restaurantId != null && state.restaurantId != widget.restaurantId) {
      // resto différent → demander confirmation
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Vider le panier ?'),
          content: const Text(
            'Tu as déjà un panier d\'un autre restaurant. Continuer remplacera son contenu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                cart.add(CartItemAdded(
                  product: widget.product,
                  restaurantId: widget.restaurantId,
                  quantity: _quantity,
                ));
                Navigator.pop(context);
              },
              child: const Text('Remplacer'),
            ),
          ],
        ),
      );
      return;
    }
    cart.add(CartItemAdded(
      product: widget.product,
      restaurantId: widget.restaurantId,
      quantity: _quantity,
    ));
    Navigator.pop(context);
  }
}
