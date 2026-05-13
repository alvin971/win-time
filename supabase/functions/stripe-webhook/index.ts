// supabase/functions/stripe-webhook/index.ts
// ============================================================================
// Stripe → Supabase webhook handler. Deno runtime. Verifies the Stripe-Signature
// header against STRIPE_WEBHOOK_SECRET, then flips wintime.orders.payment_status
// to 'paid' and records stripe_charge_id + payment_captured_at.
//
// Deploy:
//   supabase functions deploy stripe-webhook --no-verify-jwt
//   supabase secrets set STRIPE_SECRET_KEY=sk_test_... STRIPE_WEBHOOK_SECRET=whsec_...
//
// Stripe Dashboard → Developers → Webhooks → add endpoint:
//   https://supabase.0for0.com/functions/v1/stripe-webhook
// Subscribe to events: payment_intent.succeeded, payment_intent.payment_failed,
//   charge.refunded, account.updated.
//
// Audit refs: S2.2.2 (no payment), S6.2.3 (no webhook handler), S2.2.1
//   (server-side trust). This function trusts Stripe (verified signature) and
//   updates the order; the client app NEVER writes payment_status itself.
// ============================================================================

import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno&deno-std=0.224.0';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4?target=deno';

const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!;
const STRIPE_WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: '2024-12-18.acacia',
  httpClient: Stripe.createFetchHttpClient(),
});

// service_role bypasses RLS — required because this function speaks for
// Stripe, not for the user. NEVER expose this client to the frontend.
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
  db: { schema: 'wintime' },
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  const signature = req.headers.get('Stripe-Signature');
  if (!signature) return json({ error: 'missing-signature' }, 400);

  const body = await req.text();

  let event: Stripe.Event;
  try {
    // constructEventAsync is required in Deno because crypto.subtle is async.
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      STRIPE_WEBHOOK_SECRET,
    );
  } catch (e) {
    console.error('Signature verification failed:', e);
    return json({ error: 'signature' }, 400);
  }

  console.log(`[stripe-webhook] event=${event.type} id=${event.id}`);

  try {
    switch (event.type) {
      case 'payment_intent.succeeded': {
        const pi = event.data.object as Stripe.PaymentIntent;
        const orderId = pi.metadata?.order_id;
        if (!orderId) {
          console.warn('payment_intent.succeeded without order_id metadata');
          break;
        }
        const charge = pi.latest_charge as string | null;
        const { error } = await supabase
          .from('orders')
          .update({
            payment_status: 'paid',
            stripe_payment_intent_id: pi.id,
            stripe_charge_id: charge ?? null,
            payment_captured_at: new Date().toISOString(),
            is_paid: true,
          })
          .eq('id', orderId);
        if (error) throw error;
        break;
      }

      case 'payment_intent.payment_failed': {
        const pi = event.data.object as Stripe.PaymentIntent;
        const orderId = pi.metadata?.order_id;
        if (!orderId) break;
        await supabase
          .from('orders')
          .update({ payment_status: 'failed' })
          .eq('id', orderId);
        break;
      }

      case 'charge.refunded': {
        const charge = event.data.object as Stripe.Charge;
        await supabase
          .from('orders')
          .update({ payment_status: 'refunded' })
          .eq('stripe_charge_id', charge.id);
        break;
      }

      case 'account.updated': {
        // Stripe Connect account status — used to flip
        // restaurants.stripe_charges_enabled / payouts_enabled.
        const acct = event.data.object as Stripe.Account;
        await supabase
          .from('restaurants')
          .update({
            stripe_charges_enabled: !!acct.charges_enabled,
            stripe_payouts_enabled: !!acct.payouts_enabled,
            stripe_details_submitted_at: acct.details_submitted
              ? new Date().toISOString()
              : null,
          })
          .eq('stripe_account_id', acct.id);
        break;
      }

      default:
        console.log(`[stripe-webhook] unhandled type=${event.type}`);
    }
  } catch (e) {
    console.error('[stripe-webhook] handler error:', e);
    return json({ error: 'handler', detail: String(e) }, 500);
  }

  return json({ received: true });
});
