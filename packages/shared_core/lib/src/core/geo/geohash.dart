import 'dart:math' as math;

/// Implémentation pure-Dart de l'encodage Geohash (base32) + utilitaires
/// pour les requêtes Firestore par proximité géographique.
///
/// Source : algorithme standard publié par Niemeyer (2008), interprétation
/// `[lat, lng]` initialisée à `[(-90, 90), (-180, 180)]`.
class Geohash {
  Geohash._();

  static const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Précision recommandée selon le rayon de recherche.
  /// - radius <= 1.5 km   → precision 7 (~150 m × 150 m)
  /// - radius <= 5 km     → precision 6 (~1.2 km × 600 m)
  /// - radius <= 20 km    → precision 5 (~5 km × 5 km)
  /// - radius <= 100 km   → precision 4 (~40 km × 20 km)
  /// - radius <= 500 km   → precision 3
  static int precisionForRadius(double radiusKm) {
    if (radiusKm <= 1.5) return 7;
    if (radiusKm <= 5) return 6;
    if (radiusKm <= 20) return 5;
    if (radiusKm <= 100) return 4;
    if (radiusKm <= 500) return 3;
    return 2;
  }

  /// Encode (lat, lng) en geohash de la précision demandée (par défaut 7).
  static String encode(double latitude, double longitude, {int precision = 7}) {
    assert(precision >= 1 && precision <= 12);
    assert(latitude >= -90 && latitude <= 90);
    assert(longitude >= -180 && longitude <= 180);

    var latRange = [-90.0, 90.0];
    var lngRange = [-180.0, 180.0];

    final hash = StringBuffer();
    var bits = 0;
    var bit = 0;
    var even = true;

    while (hash.length < precision) {
      double mid;
      if (even) {
        mid = (lngRange[0] + lngRange[1]) / 2;
        if (longitude >= mid) {
          bits = (bits << 1) | 1;
          lngRange[0] = mid;
        } else {
          bits = bits << 1;
          lngRange[1] = mid;
        }
      } else {
        mid = (latRange[0] + latRange[1]) / 2;
        if (latitude >= mid) {
          bits = (bits << 1) | 1;
          latRange[0] = mid;
        } else {
          bits = bits << 1;
          latRange[1] = mid;
        }
      }
      even = !even;

      if (++bit == 5) {
        hash.write(_base32[bits]);
        bits = 0;
        bit = 0;
      }
    }
    return hash.toString();
  }

  /// Retourne une liste de paires (start, end) à utiliser dans des queries
  /// Firestore `where('geohash', isGreaterThanOrEqualTo: start)
  /// .where('geohash', isLessThan: end)`.
  ///
  /// Le caller doit lancer N queries en parallèle (une par range), merger
  /// les résultats, puis filtrer chaque doc avec
  /// `Geolocator.distanceBetween(...) <= radiusKm * 1000`.
  ///
  /// On calcule les 9 cellules autour de la position (la cellule centrale
  /// + 8 voisines) à la précision adaptée au radius.
  static List<({String start, String end})> boundingBoxHashes(
    double latitude,
    double longitude,
    double radiusKm,
  ) {
    final precision = precisionForRadius(radiusKm);

    // Génère un set de geohashes voisins (la cellule centrale + neighbors).
    final centerHash = encode(latitude, longitude, precision: precision);
    final neighbors = _neighbors(centerHash);
    final allHashes = {centerHash, ...neighbors};

    // Convertit chaque hash en range [hash, hash + '~'] où '~' (0x7e) est
    // strictement supérieur au plus grand char base32 ('z' = 0x7a).
    return allHashes
        .map((h) => (start: h, end: '$h~'))
        .toList(growable: false);
  }

  /// Calcule les 8 cellules adjacentes à un geohash donné.
  /// Algorithme adapté de geohash-java.
  static Set<String> _neighbors(String hash) {
    final result = <String>{};
    for (final dir in [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
      [1, 1],
      [1, -1],
      [-1, 1],
      [-1, -1],
    ]) {
      final n = _adjacent(hash, dir[0], dir[1]);
      if (n != null) result.add(n);
    }
    return result;
  }

  /// Calcule un voisin par décalage [(dLat, dLng) ∈ {-1, 0, 1}²] :
  /// méthode robuste mais coûteuse — on décode la bbox du hash, on prend
  /// le centre + un petit offset dans la direction voulue, et on ré-encode
  /// à la même précision.
  static String? _adjacent(String hash, int dLat, int dLng) {
    if (hash.isEmpty) return null;
    final bbox = _decodeBbox(hash);
    final cellLat = bbox.maxLat - bbox.minLat;
    final cellLng = bbox.maxLng - bbox.minLng;
    final centerLat = (bbox.minLat + bbox.maxLat) / 2;
    final centerLng = (bbox.minLng + bbox.maxLng) / 2;
    final newLat = centerLat + dLat * cellLat;
    final newLng = centerLng + dLng * cellLng;
    if (newLat < -90 || newLat > 90) return null;
    var lng = newLng;
    if (lng < -180) lng += 360;
    if (lng > 180) lng -= 360;
    return encode(newLat, lng, precision: hash.length);
  }

  static _Bbox _decodeBbox(String hash) {
    var latRange = [-90.0, 90.0];
    var lngRange = [-180.0, 180.0];
    var even = true;

    for (final char in hash.split('')) {
      final cd = _base32.indexOf(char);
      if (cd == -1) {
        throw ArgumentError('Invalid geohash character: $char');
      }
      for (var mask = 16; mask >= 1; mask >>= 1) {
        final bit = (cd & mask) != 0;
        if (even) {
          final mid = (lngRange[0] + lngRange[1]) / 2;
          if (bit) {
            lngRange[0] = mid;
          } else {
            lngRange[1] = mid;
          }
        } else {
          final mid = (latRange[0] + latRange[1]) / 2;
          if (bit) {
            latRange[0] = mid;
          } else {
            latRange[1] = mid;
          }
        }
        even = !even;
      }
    }
    return _Bbox(
      minLat: latRange[0],
      maxLat: latRange[1],
      minLng: lngRange[0],
      maxLng: lngRange[1],
    );
  }

  /// Distance Haversine en mètres. Backstop pour le post-filtre côté client.
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }

  static double _toRad(double deg) => deg * (math.pi / 180.0);
}

class _Bbox {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  _Bbox({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });
}
