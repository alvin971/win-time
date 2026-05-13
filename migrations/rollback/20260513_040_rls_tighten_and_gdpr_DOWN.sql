-- ============================================================================
-- ROLLBACK: 20260513_040_rls_tighten_and_gdpr.sql
-- Reverts to the pre-tightening RLS shape (cross-tenant menu read allowed).
-- ============================================================================

DROP TRIGGER  IF EXISTS orders_enforce_status_transition  ON wintime.orders;
DROP FUNCTION IF EXISTS wintime.enforce_order_status_transition();

REVOKE EXECUTE ON FUNCTION wintime.anonymize_user(UUID) FROM authenticated;
DROP FUNCTION IF EXISTS wintime.anonymize_user(UUID);

-- Restore the loose menu-read policies (every authenticated user).
DROP POLICY IF EXISTS categories_read       ON wintime.categories;
DROP POLICY IF EXISTS categories_owner_read ON wintime.categories;
CREATE POLICY categories_read
  ON wintime.categories
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS products_read         ON wintime.products;
DROP POLICY IF EXISTS products_owner_read   ON wintime.products;
CREATE POLICY products_read
  ON wintime.products
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Restore the original orders_owner_update policy (no WITH CHECK).
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
  );

-- Restore the original CASCADE FK on restaurants.owner_id.
ALTER TABLE wintime.restaurants DROP CONSTRAINT IF EXISTS restaurants_owner_id_fkey;
ALTER TABLE wintime.restaurants
  ADD CONSTRAINT restaurants_owner_id_fkey
  FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Restore the original NO ACTION on orders.customer_id (was implicit default).
ALTER TABLE wintime.orders DROP CONSTRAINT IF EXISTS orders_customer_id_fkey;
ALTER TABLE wintime.orders
  ALTER COLUMN customer_id SET NOT NULL,
  ADD CONSTRAINT orders_customer_id_fkey
  FOREIGN KEY (customer_id) REFERENCES auth.users(id);
