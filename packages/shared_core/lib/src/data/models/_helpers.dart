/// Helpers de mapping pour les models Postgres/Supabase.
///
/// Postgres → Dart : les colonnes `timestamptz` arrivent en String ISO 8601,
/// les colonnes `numeric` en double, les `text[]` en `List<dynamic>`, les
/// `jsonb` en `Map<String, dynamic>` ou `List<dynamic>`.

/// Convertit un champ row en [DateTime] de façon défensive.
DateTime? ts(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
  return null;
}

/// Sérialise un [DateTime] en String ISO 8601 (le format que Postgres attend
/// pour les colonnes `timestamptz` via PostgREST).
String? tsString(DateTime? dt) => dt?.toUtc().toIso8601String();

/// Conversion défensive vers [double] (Postgres `numeric` arrive parfois en
/// String selon la version PostgREST, parfois en num).
double? asDouble(Object? raw) {
  if (raw == null) return null;
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}

/// Conversion défensive vers [int].
int? asInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

/// Liste typée à partir d'un dynamic.
List<T> asList<T>(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<T>().toList(growable: false);
}

/// Map typée à partir d'un dynamic.
Map<String, T> asMap<T>(Object? raw) {
  if (raw is! Map) return const {};
  final result = <String, T>{};
  raw.forEach((k, v) {
    if (k is String && v is T) result[k] = v;
  });
  return result;
}
