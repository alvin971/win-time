import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/wintime_supabase_config.dart';

/// Thin wrapper around `flutter_stripe`.
///
/// Flow:
///   1. The client calls `createPaymentIntent(orderId)` which invokes the
///      `create-payment-intent` Supabase Edge Function. The function reads the
///      order server-side, applies the platform fee, and returns a `clientSecret`.
///   2. The client passes the `clientSecret` to `presentPaymentSheet()`.
///   3. Stripe handles 3DS / card entry / Apple Pay / Google Pay.
///   4. On success Stripe pings the `stripe-webhook` Edge Function which flips
///      `wintime.orders.payment_status = paid` server-side. The client app
///      then realtime-streams that change and updates the tracking UI.
///
/// The Stripe publishable key is loaded from `--dart-define STRIPE_PUBLISHABLE_KEY`
/// (matching the CI workflows in `.github/workflows/deploy_*.yml`). If the
/// publishable key is empty (e.g., a local dev run without the secret),
/// `isAvailable` returns false and the checkout falls back to cash-on-pickup.
class StripePaymentService {
  StripePaymentService._();

  static const String _publishableKey =
      String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

  static bool _initialized = false;

  /// True if a Stripe publishable key was injected at build time.
  static bool get isAvailable => _publishableKey.isNotEmpty;

  /// Initialize the SDK once. Idempotent. Safe to call from main().
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (!isAvailable) {
      debugPrint('Stripe: STRIPE_PUBLISHABLE_KEY not set, payment disabled');
      return;
    }
    Stripe.publishableKey = _publishableKey;
    Stripe.merchantIdentifier = 'merchant.com.wintime.app';
    Stripe.urlScheme = 'wintime';
    await Stripe.instance.applySettings();
    _initialized = true;
  }

  /// Calls the `create-payment-intent` Edge Function which is hosted at
  /// `<SUPABASE_URL>/functions/v1/create-payment-intent`. Returns the
  /// `clientSecret` that `presentPaymentSheet()` consumes.
  ///
  /// Throws on network / auth / server error so the caller can surface a
  /// snackbar.
  static Future<String> createPaymentIntent({required String orderId}) async {
    final supabase = Supabase.instance.client;
    final resp = await supabase.functions.invoke(
      'create-payment-intent',
      body: {'orderId': orderId},
    );
    final data = resp.data;
    if (data is! Map || data['clientSecret'] == null) {
      throw StateError(
        'create-payment-intent returned invalid payload: $data',
      );
    }
    return data['clientSecret'] as String;
  }

  /// Init + present the Stripe Payment Sheet for [orderId]. Returns true on
  /// successful payment, false on cancel, throws on hard error.
  static Future<bool> pay({
    required String orderId,
    required String merchantName,
  }) async {
    if (!isAvailable) {
      throw StateError('Stripe is not configured (STRIPE_PUBLISHABLE_KEY missing)');
    }
    await ensureInitialized();
    final clientSecret = await createPaymentIntent(orderId: orderId);

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: merchantName,
        style: ThemeMode.system,
        // Apple Pay / Google Pay default to FR country.
        applePay: const PaymentSheetApplePay(merchantCountryCode: 'FR'),
        googlePay: const PaymentSheetGooglePay(
          merchantCountryCode: 'FR',
          currencyCode: 'EUR',
        ),
      ),
    );

    try {
      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return false;
      rethrow;
    }
  }

  /// Wallet helper for `wintime.orders.payment_status` text used in the
  /// `payment_method` column.
  static const String paymentMethodCard = 'creditCard';
}

/// Replace existing `wintime.user_profiles` schema reference for callers
/// that don't want to depend on the full config import.
String get wintimeSchema => WintimeSupabaseConfig.schema;
