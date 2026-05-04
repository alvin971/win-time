-- ============================================================================
-- Win Time — RLS policies (Row Level Security)
-- Date : 2026-05-04
-- ============================================================================
-- À appliquer APRÈS 20260504_010_wintime_schema.sql.
--
-- Modèle :
-- - user_profiles : self-only read/write
-- - restaurants : public read si actif+approuvé (ou owner), write owner-only
-- - categories/products : read tout signed-in user, write owner du resto
-- - orders : customer voit les siennes, owner voit celles de son resto,
--            customer crée en pending, owner update statut, customer peut
--            cancel tant que pending
-- ============================================================================

-- ─── 1. user_profiles ─────────────────────────────────────────────────────
ALTER TABLE wintime.user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_profiles_self_select ON wintime.user_profiles;
DROP POLICY IF EXISTS user_profiles_self_insert ON wintime.user_profiles;
DROP POLICY IF EXISTS user_profiles_self_update ON wintime.user_profiles;

CREATE POLICY user_profiles_self_select
  ON wintime.user_profiles
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY user_profiles_self_insert
  ON wintime.user_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Le rôle est immuable côté client (anti-escalation)
CREATE POLICY user_profiles_self_update
  ON wintime.user_profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id AND role = (SELECT role FROM wintime.user_profiles WHERE id = auth.uid()));

-- Pas de delete : on désactive (is_active = false) au lieu

-- ─── 2. restaurants ───────────────────────────────────────────────────────
ALTER TABLE wintime.restaurants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS restaurants_public_read   ON wintime.restaurants;
DROP POLICY IF EXISTS restaurants_owner_read    ON wintime.restaurants;
DROP POLICY IF EXISTS restaurants_owner_insert  ON wintime.restaurants;
DROP POLICY IF EXISTS restaurants_owner_update  ON wintime.restaurants;
DROP POLICY IF EXISTS restaurants_owner_delete  ON wintime.restaurants;

-- Lecture publique pour tout signed-in user, uniquement si actif+approuvé
CREATE POLICY restaurants_public_read
  ON wintime.restaurants
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND is_active = TRUE
    AND is_approved = TRUE
  );

-- Le owner peut TOUJOURS lire son resto, même non-approuvé / inactif
CREATE POLICY restaurants_owner_read
  ON wintime.restaurants
  FOR SELECT
  USING (auth.uid() = owner_id);

-- Création : seul un user avec role restaurantOwner peut créer
CREATE POLICY restaurants_owner_insert
  ON wintime.restaurants
  FOR INSERT
  WITH CHECK (
    owner_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM wintime.user_profiles up
      WHERE up.id = auth.uid()
        AND up.role = 'restaurantOwner'
    )
  );

-- Update : owner uniquement, et owner_id immuable
CREATE POLICY restaurants_owner_update
  ON wintime.restaurants
  FOR UPDATE
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id AND owner_id = (SELECT owner_id FROM wintime.restaurants WHERE id = wintime.restaurants.id));

CREATE POLICY restaurants_owner_delete
  ON wintime.restaurants
  FOR DELETE
  USING (auth.uid() = owner_id);

-- ─── 3. categories ────────────────────────────────────────────────────────
ALTER TABLE wintime.categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS categories_read       ON wintime.categories;
DROP POLICY IF EXISTS categories_owner_all  ON wintime.categories;

CREATE POLICY categories_read
  ON wintime.categories
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY categories_owner_all
  ON wintime.categories
  FOR ALL
  USING (
    EXISTS (
      SELECT 1
      FROM wintime.restaurants r
      WHERE r.id = wintime.categories.restaurant_id
        AND r.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM wintime.restaurants r
      WHERE r.id = wintime.categories.restaurant_id
        AND r.owner_id = auth.uid()
    )
  );

-- ─── 4. products ──────────────────────────────────────────────────────────
ALTER TABLE wintime.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS products_read       ON wintime.products;
DROP POLICY IF EXISTS products_owner_all  ON wintime.products;

CREATE POLICY products_read
  ON wintime.products
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY products_owner_all
  ON wintime.products
  FOR ALL
  USING (
    EXISTS (
      SELECT 1
      FROM wintime.restaurants r
      WHERE r.id = wintime.products.restaurant_id
        AND r.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM wintime.restaurants r
      WHERE r.id = wintime.products.restaurant_id
        AND r.owner_id = auth.uid()
    )
  );

-- ─── 5. orders ────────────────────────────────────────────────────────────
ALTER TABLE wintime.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS orders_visible_to_party  ON wintime.orders;
DROP POLICY IF EXISTS orders_customer_create   ON wintime.orders;
DROP POLICY IF EXISTS orders_owner_update      ON wintime.orders;
DROP POLICY IF EXISTS orders_customer_cancel   ON wintime.orders;

-- Read : customer voit ses commandes, owner du resto voit les commandes de son resto
CREATE POLICY orders_visible_to_party
  ON wintime.orders
  FOR SELECT
  USING (
    customer_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM wintime.restaurants r
      WHERE r.id = wintime.orders.restaurant_id
        AND r.owner_id = auth.uid()
    )
  );

-- Création : customer uniquement, status forcément pending
CREATE POLICY orders_customer_create
  ON wintime.orders
  FOR INSERT
  WITH CHECK (
    customer_id = auth.uid()
    AND status = 'pending'
  );

-- Update : owner du resto peut tout updater (statut, prep time, etc.)
CREATE POLICY orders_owner_update
  ON wintime.orders
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM wintime.restaurants r
      WHERE r.id = wintime.orders.restaurant_id
        AND r.owner_id = auth.uid()
    )
  );

-- Update : customer peut annuler tant que pending
CREATE POLICY orders_customer_cancel
  ON wintime.orders
  FOR UPDATE
  USING (
    customer_id = auth.uid()
    AND status = 'pending'
  )
  WITH CHECK (
    customer_id = auth.uid()
    AND status = 'cancelled'
  );

-- Pas de delete : on garde l'historique
