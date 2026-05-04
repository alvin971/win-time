import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/wintime_supabase_config.dart';

/// Lecture des restaurants depuis le schéma `wintime` Supabase.
///
/// Stratégie geo : on lance N queries parallèles `geohash IN [bbox ranges]`,
/// merge en Dart, puis post-filtre via Haversine pour éliminer les false
/// positives en bord de bbox.
class SupabaseRestaurantsDataSource {
  final SupabaseClient _client;

  SupabaseRestaurantsDataSource(this._client);

  PostgrestQueryBuilder get _table =>
      _client.schema(WintimeSupabaseConfig.schema).from('restaurants');

  /// Liste les restaurants actifs+approuvés dans un rayon [radiusKm] autour
  /// de [lat]/[lng], triés par distance croissante.
  Future<List<RestaurantWithDistance>> nearbyRestaurants({
    required double lat,
    required double lng,
    double radiusKm = 10,
  }) async {
    final boxes = Geohash.boundingBoxHashes(lat, lng, radiusKm);

    // Query parallèle pour chaque bbox
    final futures = boxes.map((b) async {
      final rows = await _table
          .select()
          .gte('geohash', b.start)
          .lt('geohash', b.end)
          .eq('is_active', true)
          .eq('is_approved', true);
      return rows as List<dynamic>;
    });
    final results = await Future.wait(futures);

    // Merge + dedup par id
    final seen = <String>{};
    final entities = <RestaurantEntity>[];
    for (final rows in results) {
      for (final row in rows) {
        final map = (row as Map).cast<String, dynamic>();
        final r = RestaurantModel.fromRow(map);
        if (seen.add(r.id)) entities.add(r);
      }
    }

    // Post-filtre Haversine + tri par distance
    final withDist = <RestaurantWithDistance>[];
    for (final r in entities) {
      final d = Geohash.distanceMeters(
        lat,
        lng,
        r.address.latitude,
        r.address.longitude,
      );
      if (d <= radiusKm * 1000) {
        withDist.add(RestaurantWithDistance(restaurant: r, distanceMeters: d));
      }
    }
    withDist.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return withDist;
  }

  /// Fallback sans géoloc : tous les restos actifs+approuvés (limit 50).
  Future<List<RestaurantEntity>> allActive({int limit = 50}) async {
    final rows = await _table
        .select()
        .eq('is_active', true)
        .eq('is_approved', true)
        .order('rating', ascending: false)
        .limit(limit);
    return (rows as List<dynamic>)
        .map((r) => RestaurantModel.fromRow((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Récupère un restaurant par son ID (page détail).
  Future<RestaurantEntity?> getById(String id) async {
    final row = await _table.select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return RestaurantModel.fromRow(row);
  }
}

class RestaurantWithDistance {
  final RestaurantEntity restaurant;
  final double distanceMeters;

  const RestaurantWithDistance({
    required this.restaurant,
    required this.distanceMeters,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}
