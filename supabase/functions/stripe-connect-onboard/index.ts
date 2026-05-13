// supabase/functions/stripe-connect-onboard/index.ts
// ============================================================================
// Pro app calls this when the restaurateur taps "Activer les paiements en
// ligne" in My Restaurant settings. It creates a Stripe Connect Express
// account if one does not exist, then returns an Account Link URL that the
// app opens in a browser/in-app-browser; Stripe walks the restaurateur
// through KYC + bank-account linking; on return, Stripe pings the
// `account.updated` webhook which flips `stripe_charges_enabled`.
// ============================================================================

import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno&deno-std=0.224.0';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4?target=deno';

const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: '2024-12-18.acacia',
  httpClient: Stripe.createFetchHttpClient(),
});

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
  db: { schema: 'wintime' },
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers':
        'authorization, x-client-info, apikey, content-type',
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return json({ ok: true });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  const auth = req.headers.get('Authorization') ?? '';
  if (!auth.startsWith('Bearer ')) return json({ error: 'auth-missing' }, 401);
  const jwt = auth.slice(7);
  const userResp = await supabase.auth.getUser(jwt);
  const user = userResp.data.user;
  if (!user) return json({ error: 'auth-invalid' }, 401);

  const { restaurantId } = await req.json();
  if (!restaurantId) return json({ error: 'restaurant-id-required' }, 400);

  const { data: restaurant, error } = await supabase
    .from('restaurants')
    .select('id, owner_id, stripe_account_id, contact_email')
    .eq('id', restaurantId)
    .single();
  if (error || !restaurant) return json({ error: 'not-found' }, 404);
  if (restaurant.owner_id !== user.id) return json({ error: 'not-owner' }, 403);

  let stripeAccountId = restaurant.stripe_account_id;
  if (!stripeAccountId) {
    const account = await stripe.accounts.create({
      type: 'express',
      country: 'FR',
      email: restaurant.contact_email ?? user.email ?? undefined,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
      business_type: 'company',
    });
    stripeAccountId = account.id;
    await supabase
      .from('restaurants')
      .update({ stripe_account_id: stripeAccountId })
      .eq('id', restaurantId);
  }

  const accountLink = await stripe.accountLinks.create({
    account: stripeAccountId,
    refresh_url: 'https://wintime.fr/onboard/refresh',
    return_url: 'https://wintime.fr/onboard/done',
    type: 'account_onboarding',
  });

  return json({
    stripeAccountId,
    onboardingUrl: accountLink.url,
    expiresAt: accountLink.expires_at,
  });
});
