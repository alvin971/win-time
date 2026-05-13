import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// "Service mode" = the Pro app is actively listening for incoming orders
/// and the restaurateur cannot afford the screen to sleep / the OS to
/// background it. We toggle wakelock for the duration. On Android, the
/// foreground-service permission is declared in the manifest; combine this
/// flag with a `flutter_background_service` instance in a Sprint 2 follow-up
/// to fully detach from the UI lifecycle.
///
/// Audit S12.4. Pro must not silently miss orders during dinner service.
class ServiceMode {
  ServiceMode._();

  static bool _active = false;
  static bool get isActive => _active;

  static Future<void> enable() async {
    if (_active) return;
    try {
      await WakelockPlus.enable();
      _active = true;
      debugPrint('ServiceMode: wakelock ON');
    } catch (e) {
      debugPrint('ServiceMode.enable failed: $e');
    }
  }

  static Future<void> disable() async {
    if (!_active) return;
    try {
      await WakelockPlus.disable();
      _active = false;
      debugPrint('ServiceMode: wakelock OFF');
    } catch (e) {
      debugPrint('ServiceMode.disable failed: $e');
    }
  }

  /// Toggle helper. Returns the new state.
  static Future<bool> toggle() async {
    if (_active) {
      await disable();
    } else {
      await enable();
    }
    return _active;
  }
}
