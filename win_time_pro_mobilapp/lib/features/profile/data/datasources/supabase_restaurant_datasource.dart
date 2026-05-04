import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/wintime_supabase_config.dart';

/// Datasource Restaurant côté Pro (lecture/écriture du resto du commerçant).
///
/// Pour ce checkpoint Phase 4A, on n'expose qu'une méthode minimale :
/// récupérer le `restaurant_id` du resto possédé par le user authentifié.
/// La feature complète Mon Restaurant + Menu CRUD viendra dans un check-point
/// suivant.
class SupabaseRestaurantDataSource {
  final SupabaseClient _client;

  SupabaseRestaurantDataSource(this._client);

  /// Récupère l'ID du resto possédé par [ownerUid].
  /// Retourne null si le user n'est pas owner d'un resto.
  Future<String?> getMyRestaurantId(String ownerUid) async {
    final row = await _client
        .schema(WintimeSupabaseConfig.schema)
        .from('restaurants')
        .select('id')
        .eq('owner_id', ownerUid)
        .limit(1)
        .maybeSingle();
    return row == null ? null : row['id'] as String;
  }

  /// Récupère le doc resto complet (utile pour la page "Mon Restaurant").
  Future<Map<String, dynamic>?> getMyRestaurant(String ownerUid) async {
    return _client
        .schema(WintimeSupabaseConfig.schema)
        .from('restaurants')
        .select()
        .eq('owner_id', ownerUid)
        .limit(1)
        .maybeSingle();
  }
}
