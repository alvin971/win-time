-- ============================================================================
-- ROLLBACK: 20260504_020_wintime_rls.sql
-- Disables every RLS policy on the wintime schema. DANGER: leaves all
-- tables open to any authenticated user. Use only during emergency triage.
-- ============================================================================

DROP POLICY IF EXISTS user_profiles_self_select ON wintime.user_profiles;
DROP POLICY IF EXISTS user_profiles_self_insert ON wintime.user_profiles;
DROP POLICY IF EXISTS user_profiles_self_update ON wintime.user_profiles;
ALTER TABLE wintime.user_profiles DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS restaurants_public_read  ON wintime.restaurants;
DROP POLICY IF EXISTS restaurants_owner_read   ON wintime.restaurants;
DROP POLICY IF EXISTS restaurants_owner_insert ON wintime.restaurants;
DROP POLICY IF EXISTS restaurants_owner_update ON wintime.restaurants;
DROP POLICY IF EXISTS restaurants_owner_delete ON wintime.restaurants;
ALTER TABLE wintime.restaurants DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS categories_read      ON wintime.categories;
DROP POLICY IF EXISTS categories_owner_all ON wintime.categories;
ALTER TABLE wintime.categories DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS products_read      ON wintime.products;
DROP POLICY IF EXISTS products_owner_all ON wintime.products;
ALTER TABLE wintime.products DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS orders_visible_to_party ON wintime.orders;
DROP POLICY IF EXISTS orders_customer_create  ON wintime.orders;
DROP POLICY IF EXISTS orders_owner_update     ON wintime.orders;
DROP POLICY IF EXISTS orders_customer_cancel  ON wintime.orders;
ALTER TABLE wintime.orders DISABLE ROW LEVEL SECURITY;
