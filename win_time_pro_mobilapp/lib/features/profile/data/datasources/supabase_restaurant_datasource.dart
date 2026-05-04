import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/wintime_supabase_config.dart';

/// Datasource Restaurant côté Pro (lecture/écriture du resto du commerçant).
///
/// Lecture : `getMyRestaurantId`, `getMyRestaurant`.
/// Écriture : `createRestaurant`, `updateRestaurant`.
/// Storage : `uploadPhoto`, `deletePhoto`.
class SupabaseRestaurantDataSource {
  final SupabaseClient _client;

  SupabaseRestaurantDataSource(this._client);

  PostgrestQueryBuilder get _table =>
      _client.schema(WintimeSupabaseConfig.schema).from('restaurants');

  // ─── Reads ─────────────────────────────────────────────────────────────

  /// Récupère l'ID du resto possédé par [ownerUid].
  Future<String?> getMyRestaurantId(String ownerUid) async {
    final row = await _table
        .select('id')
        .eq('owner_id', ownerUid)
        .limit(1)
        .maybeSingle();
    return row == null ? null : row['id'] as String;
  }

  /// Récupère le doc resto complet (utile pour la page "Mon Restaurant").
  Future<Map<String, dynamic>?> getMyRestaurant(String ownerUid) async {
    return _table.select().eq('owner_id', ownerUid).limit(1).maybeSingle();
  }

  // ─── Writes ────────────────────────────────────────────────────────────

  /// Crée un nouveau restaurant et retourne l'ID Postgres généré.
  /// Le caller construit le row complet (cf. RestaurantModel.toRow côté
  /// shared_core, qui calcule automatiquement le geohash).
  Future<String> createRestaurant(Map<String, dynamic> row) async {
    final result = await _table.insert(row).select('id').single();
    return result['id'] as String;
  }

  /// Met à jour un restaurant existant (par id).
  Future<void> updateRestaurant({
    required String id,
    required Map<String, dynamic> row,
  }) async {
    await _table.update(row).eq('id', id);
  }

  /// Toggle rapide accepting_orders sans recharger le form complet.
  Future<void> setAcceptingOrders(String id, bool accepting) async {
    await _table.update({'accepting_orders': accepting}).eq('id', id);
  }

  // ─── Storage ───────────────────────────────────────────────────────────

  /// Upload une photo dans le bucket `restaurant-photos`.
  ///
  /// Path = `{ownerUid}/{kind}.{ext}` pour logo/banner (1 seul fichier
  /// remplace l'ancien), `{ownerUid}/gallery/{filename}` pour la galerie.
  ///
  /// La RLS storage exige que la 1re partie du path soit `auth.uid()`,
  /// donc [ownerUid] DOIT être l'UID du user connecté.
  ///
  /// Retourne l'URL publique de la photo.
  Future<String> uploadPhoto({
    required String ownerUid,
    required String kind, // 'logo' | 'banner' | 'gallery/{name}'
    required Uint8List bytes,
    required String contentType, // 'image/jpeg', 'image/png', 'image/webp'
  }) async {
    const bucket = 'restaurant-photos';
    final path = '$ownerUid/$kind';
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

  /// Supprime une photo (utile pour retirer un logo/banner ou une photo
  /// galerie). Le path doit commencer par l'UID du user (RLS).
  Future<void> deletePhoto({required String fullPath}) async {
    await _client.storage.from('restaurant-photos').remove([fullPath]);
  }
}
