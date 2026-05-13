import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin persistence layer for the cart. Persists the cart on every change so
/// a crash/backgrounding does not wipe the user's selections. We use
/// SharedPreferences (already in pubspec) rather than introducing
/// `hydrated_bloc` to keep dep count down. Audit S2.2.15.
///
/// Format: a single JSON string under the key `cart_state_v1`. Bumping the
/// `_v1` suffix invalidates older shapes; we read tolerantly.
class CartPersistence {
  CartPersistence._();

  static const String _key = 'cart_state_v1';
  static const Duration _ttl = Duration(hours: 8); // longer than any service

  /// Persist a cart snapshot. Lines is a list of `{product_id, quantity}`
  /// records (we re-fetch the live product data at next load — prices may
  /// have changed).
  static Future<void> save({
    required String? restaurantId,
    required List<({String productId, int quantity})> lines,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'restaurantId': restaurantId,
        'lines': lines
            .map((l) => {'productId': l.productId, 'quantity': l.quantity})
            .toList(),
        'savedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await prefs.setString(_key, jsonEncode(payload));
    } catch (e) {
      debugPrint('CartPersistence.save failed: $e');
    }
  }

  /// Load. Returns null if absent, malformed, or older than [_ttl].
  static Future<({String? restaurantId, List<({String productId, int quantity})> lines})?>
      load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final j = jsonDecode(raw);
      if (j is! Map) return null;

      final savedAt = DateTime.tryParse((j['savedAt'] as String?) ?? '');
      if (savedAt == null) return null;
      if (DateTime.now().toUtc().difference(savedAt) > _ttl) {
        await prefs.remove(_key);
        return null;
      }

      final lines = <({String productId, int quantity})>[];
      final list = j['lines'];
      if (list is List) {
        for (final raw in list) {
          if (raw is! Map) continue;
          final pid = raw['productId'];
          final q = raw['quantity'];
          if (pid is String && q is int && q > 0) {
            lines.add((productId: pid, quantity: q));
          }
        }
      }
      return (restaurantId: j['restaurantId'] as String?, lines: lines);
    } catch (e) {
      debugPrint('CartPersistence.load failed: $e');
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
