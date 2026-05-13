import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Wraps `runApp` with Sentry crash reporting.
///
/// The DSN is loaded from `--dart-define SENTRY_DSN_PRO=...`. If empty,
/// Sentry is skipped and the app runs unmodified — useful for local dev
/// without burning quota.
///
/// `beforeSend` filters known PII (FCM tokens, JWT bearer strings) from
/// breadcrumbs and exception messages.
Future<void> runWithSentry(Widget Function() appBuilder) async {
  const dsn = String.fromEnvironment('SENTRY_DSN_PRO');
  if (dsn.isEmpty) {
    debugPrint('Sentry: SENTRY_DSN_PRO not set, skipping init');
    runApp(appBuilder());
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = dsn;
      options.tracesSampleRate = kDebugMode ? 1.0 : 0.05;
      options.profilesSampleRate = 0.0; // off until we tune perf
      options.sendDefaultPii = false;
      options.environment = kReleaseMode ? 'production' : 'development';
      options.attachStacktrace = true;
      options.enableAutoPerformanceTracing = true;
      options.beforeSend = (event, hint) async {
        // Strip anything that looks like an FCM token or JWT from breadcrumbs.
        final scrubbed = event.copyWith(
          breadcrumbs: event.breadcrumbs?.map(_scrubBreadcrumb).toList(),
        );
        return scrubbed;
      };
    },
    appRunner: () => runApp(appBuilder()),
  );
}

Breadcrumb _scrubBreadcrumb(Breadcrumb b) {
  final msg = b.message;
  if (msg == null) return b;
  final scrubbed = msg
      .replaceAll(RegExp(r'eyJ[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-\.]{20,}'),
          '<jwt-redacted>')
      .replaceAll(RegExp(r'[A-Za-z0-9_\-:]{140,}'), '<fcm-token-redacted>');
  return b.copyWith(message: scrubbed);
}
