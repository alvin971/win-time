-- ============================================================================
-- Win Time — Pickup code surface + Stripe payment columns + "saved vs Uber"
-- Date    : 2026-05-13
-- Audit refs: S3.1.2 (pickup verification), S2.2.2 + S6.2.3 (Stripe), S7.3
--   (save-vs-Uber-Eats marketing badge).
--
-- IDEMPOTENT.
-- ============================================================================

-- ─── 1. Pickup code on orders ───────────────────────────────────────────────
-- 6-digit zero-padded code per order. Generated server-side on insert. Shown
-- to the customer in the order tracking page once status=ready; the Pro app
-- has a "Verify code" input on ready orders to confirm pickup.
ALTER TABLE wintime.orders
  ADD COLUMN IF NOT EXISTS pickup_code TEXT;

ALTER TABLE wintime.orders
  DROP CONSTRAINT IF EXISTS orders_pickup_code_format;
ALTER TABLE wintime.orders
  ADD CONSTRAINT orders_pickup_code_format
  CHECK (pickup_code IS NULL OR pickup_code ~ '^[0-9]{6}$');

CREATE OR REPLACE FUNCTION wintime.gen_pickup_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.pickup_code IS NULL THEN
    -- 100k-1M range to keep it always 6 digits.
    NEW.pickup_code := LPAD((100000 + (random() * 899999)::INTEGER)::TEXT, 6, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS orders_gen_pickup_code ON wintime.orders;
CREATE TRIGGER orders_gen_pickup_code
  BEFORE INSERT ON wintime.orders
  FOR EACH ROW
  EXECUTE FUNCTION wintime.gen_pickup_code();

-- ─── 2. Stripe columns on orders ────────────────────────────────────────────
-- Populated by the Edge Function `stripe-webhook` on `payment_intent.succeeded`.
-- The client never writes these.
ALTER TABLE wintime.orders
  ADD COLUMN IF NOT EXISTS stripe_payment_intent_id TEXT,
  ADD COLUMN IF NOT EXISTS stripe_charge_id          TEXT,
  ADD COLUMN IF NOT EXISTS payment_captured_at       TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS orders_stripe_pi_uniq
  ON wintime.orders(stripe_payment_intent_id)
  WHERE stripe_payment_intent_id IS NOT NULL;

-- ─── 3. Stripe Connect account on restaurants ──────────────────────────────
ALTER TABLE wintime.restaurants
  ADD COLUMN IF NOT EXISTS stripe_account_id            TEXT,
  ADD COLUMN IF NOT EXISTS stripe_charges_enabled       BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS stripe_payouts_enabled       BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS stripe_details_submitted_at  TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS restaurants_stripe_account_uniq
  ON wintime.restaurants(stripe_account_id)
  WHERE stripe_account_id IS NOT NULL;

-- ─── 4. "Saved vs Uber Eats" — generated column for marketing ──────────────
-- 30% reflects the upper-band aggregator commission (audit S4.2). Stored
-- as a generated column so reads are free and we can sum it per restaurant.
ALTER TABLE wintime.orders
  DROP COLUMN IF EXISTS saved_vs_aggregator_cents;
ALTER TABLE wintime.orders
  ADD COLUMN saved_vs_aggregator_cents BIGINT
  GENERATED ALWAYS AS (ROUND(total_amount * 100 * 0.30)::BIGINT) STORED;

COMMENT ON COLUMN wintime.orders.saved_vs_aggregator_cents IS
  'Estimated commission the restaurateur did NOT pay (vs. 30% Uber Eats/Deliveroo). Used for the "save vs Uber Eats" badge.';

-- ─── 5. restaurant_members — proper multi-staff support ────────────────────
-- Today: every owner-side RLS check uses `restaurants.owner_id = auth.uid()`.
-- restaurantManager and restaurantStaff are dead enum values (audit S2.2.8).
-- This table makes them real.
CREATE TABLE IF NOT EXISTS wintime.restaurant_members (
  restaurant_id UUID         NOT NULL REFERENCES wintime.restaurants(id) ON DELETE CASCADE,
  user_id       UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role          TEXT         NOT NULL CHECK (role IN ('owner', 'manager', 'staff')),
  invited_by    UUID         REFERENCES auth.users(id) ON DELETE SET NULL,
  joined_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  PRIMARY KEY (restaurant_id, user_id)
);

CREATE INDEX IF NOT EXISTS restaurant_members_user_idx
  ON wintime.restaurant_members(user_id);

-- Backfill: every existing owner becomes a 'owner' member row.
INSERT INTO wintime.restaurant_members (restaurant_id, user_id, role)
SELECT id, owner_id, 'owner'
FROM wintime.restaurants
ON CONFLICT (restaurant_id, user_id) DO NOTHING;

GRANT SELECT, INSERT, UPDATE, DELETE
  ON wintime.restaurant_members TO authenticated;
GRANT SELECT
  ON wintime.restaurant_members TO anon;

ALTER TABLE wintime.restaurant_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS members_self_read       ON wintime.restaurant_members;
DROP POLICY IF EXISTS members_owner_manage    ON wintime.restaurant_members;

-- A user can always see their own memberships.
CREATE POLICY members_self_read
  ON wintime.restaurant_members
  FOR SELECT
  USING (user_id = auth.uid());

-- Only owners can add/remove members of their restaurant.
CREATE POLICY members_owner_manage
  ON wintime.restaurant_members
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM wintime.restaurants r
      WHERE r.id = wintime.restaurant_members.restaurant_id
        AND r.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM wintime.restaurants r
      WHERE r.id = wintime.restaurant_members.restaurant_id
        AND r.owner_id = auth.uid()
    )
  );

-- ─── 6. Helper view for "is the caller a member of restaurant X" ───────────
CREATE OR REPLACE VIEW wintime.my_restaurants AS
SELECT m.restaurant_id, m.role
FROM wintime.restaurant_members m
WHERE m.user_id = auth.uid();

GRANT SELECT ON wintime.my_restaurants TO authenticated;
