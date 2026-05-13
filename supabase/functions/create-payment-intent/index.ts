// supabase/functions/create-payment-intent/index.ts
// ============================================================================
// Called by the Client app immediately after the order has been inserted into
// wintime.orders (the server-side trigger has already validated/recomputed
// the canonical amounts). This function:
//   1. Reads the order from Supabase (RLS allows the customer to see their own).
//   2. Reads the restaurant's stripe_account_id.
//   3. Creates a Stripe PaymentIntent with:
//        - application_fee_amount = 2.5% platform fee
//        - transfer_data.destination = restaurant's connected account
//   4. Returns the client_secret.
//
// The Client app uses the client_secret in flutter_stripe's PaymentSheet.
//
// Deploy:
//   supabase functions deploy create-payment-intent
//
// Env (already set if you deployed stripe-webhook):
//   STRIPE_SECRET_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// ============================================================================

import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno&deno-std=0.224.0';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4?target=deno';

const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const PLATFORM_FEE_PERCENT = 0.025; // 2.5 % — see audit S5 (transaction-fee model)

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: '2024-12-18.acacia',
  httpClient: Stripe.createFetchHttpClient(),
});

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
  db: { schema: 'wintime' },
});

function json(body: unknown, status = 200): Response {
  const headers = {
    'Content-Type': 'application/json',
    // CORS for the Client app (web + native)
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type',
  };
  return new Response(JSON.stringify(body), { status, headers });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return json({ ok: true });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  // The Client app must send its user JWT so we can verify the caller is the
  // order's customer. We extract it from the Authorization header (the
  // Supabase Auth client always attaches it).
  const auth = req.headers.get('Authorization') ?? '';
  if (!auth.startsWith('Bearer ')) return json({ error: 'auth-missing' }, 401);
  const jwt = auth.slice(7);

  const userResp = await supabase.auth.getUser(jwt);
  const user = userResp.data.user;
  if (!user) return json({ error: 'auth-invalid' }, 401);

  let body: { orderId?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'bad-json' }, 400);
  }
  if (!body.orderId) return json({ error: 'order-id-required' }, 400);

  // Read the order; refuse if it isn't the caller's.
  const { data: order, error: orderErr } = await supabase
    .from('orders')
    .select(
      'id, customer_id, restaurant_id, total_amount, payment_status, stripe_payment_intent_id',
    )
    .eq('id', body.orderId)
    .single();
  if (orderErr || !order) {
    console.error('order lookup:', orderErr);
    return json({ error: 'order-not-found' }, 404);
  }
  if (order.customer_id !== user.id) {
    return json({ error: 'not-your-order' }, 403);
  }
  if (order.payment_status === 'paid') {
    return json({ error: 'already-paid' }, 409);
  }

  // Idempotency: if a PI already exists for this order, just return its secret.
  if (order.stripe_payment_intent_id) {
    const existing = await stripe.paymentIntents.retrieve(
      order.stripe_payment_intent_id,
    );
    return json({
      paymentIntentId: existing.id,
      clientSecret: existing.client_secret,
      idempotent: true,
    });
  }

  const { data: restaurant, error: restErr } = await supabase
    .from('restaurants')
    .select('stripe_account_id, stripe_charges_enabled')
    .eq('id', order.restaurant_id)
    .single();
  if (restErr || !restaurant) {
    return json({ error: 'restaurant-not-found' }, 404);
  }
  if (!restaurant.stripe_account_id || !restaurant.stripe_charges_enabled) {
    return json(
      { error: 'restaurant-stripe-not-onboarded' },
      400,
    );
  }

  const amountCents = Math.round(Number(order.total_amount) * 100);
  if (amountCents <= 0) return json({ error: 'amount-invalid' }, 400);
  const platformFeeCents = Math.round(amountCents * PLATFORM_FEE_PERCENT);

  const pi = await stripe.paymentIntents.create({
    amount: amountCents,
    currency: 'eur',
    application_fee_amount: platformFeeCents,
    transfer_data: { destination: restaurant.stripe_account_id },
    automatic_payment_methods: { enabled: true },
    metadata: {
      order_id: order.id,
      restaurant_id: order.restaurant_id,
      customer_id: order.customer_id,
    },
  });

  // Eagerly persist the PI id so the webhook + retries can correlate.
  await supabase
    .from('orders')
    .update({ stripe_payment_intent_id: pi.id })
    .eq('id', order.id);

  return json({
    paymentIntentId: pi.id,
    clientSecret: pi.client_secret,
    idempotent: false,
  });
});
