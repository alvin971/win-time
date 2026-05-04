import 'package:cloud_firestore/cloud_firestore.dart';

/// Convertit un champ Firestore en [DateTime] de façon défensive.
///
/// Accepte [Timestamp], [DateTime], [String] (ISO 8601), [int] (epoch ms).
/// Retourne `null` pour tout autre type ou valeur null.
DateTime? ts(Object? raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
  return null;
}

/// Conversion défensive vers [double] (Firestore renvoie parfois int au
/// lieu de double pour les montants entiers).
double? asDouble(Object? raw) {
  if (raw == null) return null;
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}

/// Liste typée à partir d'un dynamic (List<dynamic> Firestore → List<T>).
List<T> asList<T>(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<T>().toList(growable: false);
}

/// Map<String, T> à partir d'un dynamic.
Map<String, T> asMap<T>(Object? raw) {
  if (raw is! Map) return const {};
  final result = <String, T>{};
  raw.forEach((k, v) {
    if (k is String && v is T) result[k] = v;
  });
  return result;
}
