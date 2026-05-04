import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/location_service.dart';
import '../../data/datasources/supabase_restaurants_datasource.dart';

/// Liste des restaurants à proximité du user, alimentée par Supabase.
///
/// Comportement :
/// 1. Demande permission location → récupère position
/// 2. Query par bbox geohash + post-filtre Haversine
/// 3. Tri par distance croissante
/// 4. Fallback sans géoloc : tous les restos actifs (limit 50)
class RestaurantsListPage extends StatefulWidget {
  const RestaurantsListPage({super.key});

  @override
  State<RestaurantsListPage> createState() => _RestaurantsListPageState();
}

class _RestaurantsListPageState extends State<RestaurantsListPage> {
  late final SupabaseRestaurantsDataSource _dataSource;
  final _locationService = LocationService();

  bool _loading = true;
  String? _error;
  List<RestaurantWithDistance>? _withDistance;
  List<RestaurantEntity>? _allRestaurants;
  Position? _position;

  @override
  void initState() {
    super.initState();
    _dataSource = SupabaseRestaurantsDataSource(Supabase.instance.client);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _position = position;
        final results = await _dataSource.nearbyRestaurants(
          lat: position.latitude,
          lng: position.longitude,
          radiusKm: 15,
        );
        if (!mounted) return;
        setState(() {
          _withDistance = results;
          _allRestaurants = null;
          _loading = false;
        });
      } else {
        // Pas de géoloc → fallback liste complète
        final all = await _dataSource.allActive();
        if (!mounted) return;
        setState(() {
          _withDistance = null;
          _allRestaurants = all;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _bootstrap,
            tooltip: 'Actualiser',
          ),
        ],
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur : $_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _bootstrap, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final cards = <Widget>[];
    if (_withDistance != null) {
      cards.add(_HeaderText(
        text: _position == null
            ? 'Restaurants à proximité'
            : '${_withDistance!.length} restaurant${_withDistance!.length > 1 ? "s" : ""} dans un rayon de 15 km',
      ));
      for (final r in _withDistance!) {
        cards.add(_RestaurantCard(
          restaurant: r.restaurant,
          distanceLabel: r.formattedDistance,
        ));
      }
    } else if (_allRestaurants != null) {
      cards.add(const _HeaderText(
        text: 'Géolocalisation indisponible — affichage de tous les restaurants',
      ));
      for (final r in _allRestaurants!) {
        cards.add(_RestaurantCard(restaurant: r));
      }
    }

    if (cards.length == 1) {
      // Pas de restos
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_food, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Aucun restaurant trouvé.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _bootstrap,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: cards,
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final RestaurantEntity restaurant;
  final String? distanceLabel;
  const _RestaurantCard({required this.restaurant, this.distanceLabel});

  @override
  Widget build(BuildContext context) {
    final hasLogo = (restaurant.logoUrl ?? '').isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/home/restaurants/${restaurant.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner image en haut (si dispo)
            if ((restaurant.bannerUrl ?? '').isNotEmpty)
              SizedBox(
                height: 140,
                child: CachedNetworkImage(
                  imageUrl: restaurant.bannerUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.orange.shade50,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.orange.shade50,
                    child: const Icon(Icons.restaurant, size: 48, color: Colors.orange),
                  ),
                ),
              ),
            Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: hasLogo
                      ? CachedNetworkImage(
                          imageUrl: restaurant.logoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.orange.shade50,
                            child: const Icon(Icons.restaurant,
                                color: Colors.orange, size: 32),
                          ),
                        )
                      : Container(
                          color: Colors.orange.shade50,
                          child: const Icon(Icons.restaurant,
                              color: Colors.orange, size: 32),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (restaurant.slogan != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        restaurant.slogan!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _Chip(
                          icon: Icons.local_dining,
                          label: restaurant.cuisineType.displayName,
                        ),
                        _Chip(
                          icon: Icons.euro,
                          label: restaurant.priceRange.symbol,
                        ),
                        if (restaurant.rating != null)
                          _Chip(
                            icon: Icons.star,
                            label: restaurant.rating!.toStringAsFixed(1),
                            color: Colors.amber,
                          ),
                        if (distanceLabel != null)
                          _Chip(
                            icon: Icons.location_on,
                            label: distanceLabel!,
                            color: Colors.blue,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _Chip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey[700]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
