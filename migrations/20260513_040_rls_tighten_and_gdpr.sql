-- ============================================================================
-- Win Time — RLS tightening + GDPR anonymization + safer cascades
-- Date    : 2026-05-13
-- Audit refs: S2.2.5 (no deletion path), S2.2.6 (no state machine), S2.2.9
--   (cross-tenant menu scrape), S8.2.1 (anonymization fn), S8.2.2 (CASCADE
--   destroys commerce records), S12.3.4 (GDPR).
--
-- IDEMPOTENT. Safe to re-run.
-- ============================================================================

-- ─── 1. Restrict menu reads to approved active restaurants ───────────────────
-- Today every authenticated user can SELECT every category/product across
-- every restaurant including unapproved drafts. Restrict to approved+active.
-- The owner still sees their own drafts via a second policy.

DROP POLICY IF EXISTS categories_read       ON wintime.categories;
DROP POLICY IF EXISTS categories_owner_read ON wintime.categories;
DROP POLICY IF EXISTS products_read         ON wintime.products;
DROP POLICY IF EXISTS products_owner_read   ON wintime.products;

CREATE POLICY categories_read
  ON wintime.categories
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM wintime.restaurants r
      WHERE r.id = wintime.categories.restaurant_id
        AND r.is_active = TRUE
        AND r.is_approved = TRUE
    )
  );

-- Owner can always read own categories, including drafts.
CREATE POLICY categories_owner_read
  ON wintime.categories
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM wintime.restaurants r
      WHERE r.id = wintime.categories.restaurant_id
        AND r.owner_id = auth.uid()
    )
  );

CREATE POLICY products_read
  ON wintime.products
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM wintime.restaurants r
      WHERE r.id = wintime.products.restaurant_id
        AND r.is_active = TRUE
        AND r.is_approved = TRUE
    )
  );

CREATE POLICY products_owner_read
  ON wintime.products
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM wintime.restaurants r
      WHERE r.id = wintime.products.restaurant_id
        AND r.owner_id = auth.uid()
    )
  );


-- ─── 2. Loosen the ON DELETE CASCADE to SET NULL via tombstone user ─────────
-- Currently deleting an auth.users row cascades to user_profiles AND
-- restaurants AND (via products/categories) the entire menu. That destroys
-- commerce records that French law (Code de commerce L123-22) requires to be
-- kept for 10 years.
--
-- Strategy: keep CASCADE on user_profiles (the profile is *about* the user),
-- but change restaurants.owner_id and orders.customer_id to SET NULL with a
-- tombstone fallback if needed.

-- 2.a. orders.customer_id — was NO ACTION (would block deletion). Make it
-- explicit SET NULL so an anonymization can wipe the FK without losing the row.
ALTER TABLE wintime.orders
  DROP CONSTRAINT IF EXISTS orders_customer_id_fkey;

ALTER TABLE wintime.orders
  ADD CONSTRAINT orders_customer_id_fkey
  FOREIGN KEY (customer_id) REFERENCES auth.users(id)
  ON DELETE SET NULL;

ALTER TABLE wintime.orders
  ALTER COLUMN customer_id DROP NOT NULL;

-- 2.b. restaurants.owner_id — was CASCADE. Switch to RESTRICT so a delete
-- of an owner with active restaurants FAILS loudly (we want manual review
-- before destroying a restaurant + its menu + its orders).
ALTER TABLE wintime.restaurants
  DROP CONSTRAINT IF EXISTS restaurants_owner_id_fkey;

ALTER TABLE wintime.restaurants
  ADD CONSTRAINT restaurants_owner_id_fkey
  FOREIGN KEY (owner_id) REFERENCES auth.users(id)
  ON DELETE RESTRICT;


-- ─── 3. anonymize_user() — GDPR Article 17 (right to erasure) ───────────────
-- Removes PII but keeps the row for FK integrity + commerce/audit retention.
-- Called from the in-app "Delete my account" button via the authenticated
-- user's JWT; SECURITY DEFINER lets it sidestep RLS to walk all the user's
-- rows, but only with their own auth.uid() — we explicitly assert that.

CREATE OR REPLACE FUNCTION wintime.anonymize_user(target_uid UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = wintime, public, pg_temp
AS $$
DECLARE
  caller_uid UUID := auth.uid();
BEGIN
  -- Only the user themselves may erase themselves. service_role can pass
  -- target_uid explicitly without an auth context (caller_uid IS NULL).
  IF caller_uid IS NOT NULL AND caller_uid <> target_uid THEN
    RAISE EXCEPTION 'permission denied: cannot anonymize another user (%, %)',
      caller_uid, target_uid;
  END IF;

  -- 3.a. Wipe profile PII (keep row for FK from orders.snapshot/customer_id).
  UPDATE wintime.user_profiles
  SET email             = 'deleted-' || id || '@wintime.deleted',
      first_name        = '',
      last_name         = '',
      phone_number      = NULL,
      profile_image_url = NULL,
      is_active         = FALSE
  WHERE id = target_uid;

  -- 3.b. Wipe order PII snapshots (the JSONB customer_info + free-text fields)
  -- but keep amount/items/status — those are accounting records.
  UPDATE wintime.orders
  SET customer_info = jsonb_build_object(
        'name', 'Compte supprimé',
        'phoneNumber', NULL,
        'email', NULL
      ),
      special_instructions = NULL,
      review = NULL
  WHERE customer_id = target_uid;

  -- 3.c. NULL the FK so a subsequent auth.users delete doesn't RESTRICT.
  UPDATE wintime.orders
  SET customer_id = NULL
  WHERE customer_id = target_uid;

  -- 3.d. We do NOT auto-delete restaurants the user owns. A restaurant
  -- closure is a deliberate operational decision; if the user owns any,
  -- the auth.users row deletion later will RESTRICT and we surface a
  -- separate "transfer or close your restaurants first" message in the UI.
END;
$$;

REVOKE ALL ON FUNCTION wintime.anonymize_user(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION wintime.anonymize_user(UUID) TO authenticated;


-- ─── 4. Order state-machine enforcement on UPDATE ───────────────────────────
-- The existing `orders_owner_update` had no WITH CHECK — owner could write
-- any status. Add a trigger that whitelists legal transitions and
-- server-side stamps the *_at timestamps.

CREATE OR REPLACE FUNCTION wintime.enforce_order_status_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  legal BOOLEAN := FALSE;
BEGIN
  -- Allow the trigger itself to set timestamps; only check status transitions.
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  -- Whitelisted transitions:
  --   pending     → accepted | rejected | cancelled
  --   accepted    → preparing | cancelled | rejected
  --   preparing   → ready | cancelled
  --   ready       → completed | cancelled
  --   completed   → (terminal — no transition)
  --   cancelled   → (terminal)
  --   rejected    → (terminal)
  CASE OLD.status
    WHEN 'pending'    THEN legal := NEW.status IN ('accepted', 'rejected', 'cancelled');
    WHEN 'accepted'   THEN legal := NEW.status IN ('preparing', 'cancelled', 'rejected');
    WHEN 'preparing'  THEN legal := NEW.status IN ('ready', 'cancelled');
    WHEN 'ready'      THEN legal := NEW.status IN ('completed', 'cancelled');
    ELSE                   legal := FALSE; -- completed/cancelled/rejected are terminal
  END CASE;

  IF NOT legal THEN
    RAISE EXCEPTION 'illegal order status transition: % → %', OLD.status, NEW.status;
  END IF;

  -- Server-side timestamps (do not trust client clock).
  IF NEW.status = 'accepted'  AND NEW.accepted_at  IS NULL THEN NEW.accepted_at  := NOW(); END IF;
  IF NEW.status = 'ready'     AND NEW.ready_at     IS NULL THEN NEW.ready_at     := NOW(); END IF;
  IF NEW.status = 'completed' AND NEW.completed_at IS NULL THEN NEW.completed_at := NOW(); END IF;
  IF NEW.status IN ('cancelled', 'rejected') AND NEW.cancelled_at IS NULL THEN
    NEW.cancelled_at := NOW();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS orders_enforce_status_transition ON wintime.orders;
CREATE TRIGGER orders_enforce_status_transition
  BEFORE UPDATE ON wintime.orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION wintime.enforce_order_status_transition();


-- ─── 5. WITH CHECK on orders_owner_update (was missing) ─────────────────────
-- Block owner from re-pointing the order at a different restaurant.

DROP POLICY IF EXISTS orders_owner_update ON wintime.orders;
CREATE POLICY orders_owner_update
  ON wintime.orders
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM wintime.restaurants r
      WHERE r.id = wintime.orders.restaurant_id
        AND r.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM wintime.restaurants r
      WHERE r.id = wintime.orders.restaurant_id
        AND r.owner_id = auth.uid()
    )
    AND restaurant_id = (SELECT restaurant_id FROM wintime.orders WHERE id = wintime.orders.id)
    AND customer_id   IS NOT DISTINCT FROM (SELECT customer_id FROM wintime.orders WHERE id = wintime.orders.id)
    AND order_number  = (SELECT order_number FROM wintime.orders WHERE id = wintime.orders.id)
  );


-- ─── 6. Sanity: confirm RLS is still ENABLED on all wintime tables ──────────
-- This is verification, not enforcement. A future migration accidentally
-- DISABLE RLS would silently destroy the privacy boundary.
DO $$
DECLARE
  bad_table TEXT;
BEGIN
  SELECT relname INTO bad_table
  FROM pg_class
  WHERE relkind = 'r'
    AND relnamespace = 'wintime'::regnamespace
    AND NOT relrowsecurity
  LIMIT 1;
  IF bad_table IS NOT NULL THEN
    RAISE EXCEPTION 'RLS is disabled on wintime.% — refusing to apply migration', bad_table;
  END IF;
END $$;
