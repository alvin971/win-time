-- ============================================================================
-- Win Time — schéma `wintime` initial
-- Date : 2026-05-04
-- ============================================================================
-- Crée le schéma dédié `wintime` dans le Postgres Supabase partagé avec
-- Mentality. Aucune collision avec `public` (toutes les tables Mentality
-- utilisent des noms WAIS-spécifiques).
--
-- IMPORTANT — avant d'appliquer ce script, ajouter `wintime` à la variable
-- d'env `PGRST_DB_SCHEMAS` du conteneur supabase-rest, sinon PostgREST ne
-- verra pas les tables et `GET /rest/v1/restaurants` retournera 404.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS wintime;
COMMENT ON SCHEMA wintime IS 'Données Win Time (commerçants restaurants + clients). Isolé de Mentality.';

-- Pour gen_random_uuid() (déjà actif sur ce projet, IF NOT EXISTS pour idempotence)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─── 1. user_profiles ─────────────────────────────────────────────────────
-- Mirror Win Time du auth.users (Supabase Auth gère les comptes, on ajoute
-- le rôle métier + données profil ici).
CREATE TABLE IF NOT EXISTS wintime.user_profiles (
  id                  UUID         PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email               TEXT         NOT NULL,
  first_name          TEXT,
  last_name           TEXT,
  phone_number        TEXT,
  profile_image_url   TEXT,
  role                TEXT         NOT NULL CHECK (role IN ('client', 'restaurantOwner', 'restaurantManager', 'restaurantStaff', 'admin')),
  is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
  is_email_verified   BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  last_login_at       TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS user_profiles_role_idx ON wintime.user_profiles(role);
CREATE INDEX IF NOT EXISTS user_profiles_email_idx ON wintime.user_profiles(LOWER(email));

COMMENT ON TABLE wintime.user_profiles IS 'Profil utilisateur Win Time, FK auth.users. Le rôle distingue client / commerçant / admin.';

-- ─── 2. restaurants ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wintime.restaurants (
  id                       UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id                 UUID              NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  name                     TEXT              NOT NULL,
  description              TEXT,
  slogan                   TEXT,

  cuisine_type             TEXT              NOT NULL,
  price_range              TEXT              NOT NULL CHECK (price_range IN ('budget', 'moderate', 'expensive', 'luxury')),
  price_level              SMALLINT          NOT NULL CHECK (price_level BETWEEN 1 AND 4),

  -- Adresse aplatie (colonnes pour query, lat/lng pour geo, plus le geohash pour bbox)
  address_street           TEXT              NOT NULL,
  address_city             TEXT              NOT NULL,
  address_postal_code      TEXT              NOT NULL,
  address_country          TEXT              NOT NULL DEFAULT 'France',
  latitude                 DOUBLE PRECISION  NOT NULL,
  longitude                DOUBLE PRECISION  NOT NULL,
  geohash                  TEXT              NOT NULL,

  -- Contact
  contact_email            TEXT,
  contact_phone            TEXT,
  contact_website          TEXT,

  -- Réseaux sociaux (JSONB léger — souvent vide)
  social_links             JSONB,

  -- Médias
  logo_url                 TEXT,
  banner_url               TEXT,
  gallery_images           TEXT[]            NOT NULL DEFAULT '{}',

  -- Heures d'ouverture (structure complexe — JSONB)
  business_hours           JSONB             NOT NULL,
  closed_dates             DATE[]            NOT NULL DEFAULT '{}',

  -- Statut
  is_active                BOOLEAN           NOT NULL DEFAULT TRUE,
  is_approved              BOOLEAN           NOT NULL DEFAULT FALSE,
  accepting_orders         BOOLEAN           NOT NULL DEFAULT TRUE,
  average_preparation_time SMALLINT          NOT NULL DEFAULT 30,
  max_concurrent_orders    SMALLINT,

  rating                   DOUBLE PRECISION,
  total_reviews            INTEGER           NOT NULL DEFAULT 0,

  -- Dénormalisation pour rendu rapide côté Client (liste catégories sans charger sub-collection)
  menu_category_ids        UUID[]            NOT NULL DEFAULT '{}',

  created_at               TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

-- Index pour la query découverte (active + approved + bbox geohash)
CREATE INDEX IF NOT EXISTS restaurants_geohash_active_idx
  ON wintime.restaurants(geohash)
  WHERE is_active = TRUE AND is_approved = TRUE;

-- Index pour le Pro (récupérer mon restaurant)
CREATE INDEX IF NOT EXISTS restaurants_owner_idx ON wintime.restaurants(owner_id);

-- Index général sur statut
CREATE INDEX IF NOT EXISTS restaurants_active_approved_idx
  ON wintime.restaurants(is_active, is_approved);

COMMENT ON TABLE wintime.restaurants IS 'Restaurants Win Time. Geohash auto-calculé côté client/seed.';

-- ─── 3. categories ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wintime.categories (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id   UUID         NOT NULL REFERENCES wintime.restaurants(id) ON DELETE CASCADE,
  name            TEXT         NOT NULL,
  description     TEXT,
  icon_url        TEXT,
  display_order   SMALLINT     NOT NULL DEFAULT 0,
  is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS categories_restaurant_idx
  ON wintime.categories(restaurant_id, display_order)
  WHERE is_active = TRUE;

-- ─── 4. products ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wintime.products (
  id                          UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id               UUID              NOT NULL REFERENCES wintime.restaurants(id) ON DELETE CASCADE,
  category_id                 UUID              NOT NULL REFERENCES wintime.categories(id) ON DELETE CASCADE,

  name                        TEXT              NOT NULL,
  description                 TEXT              NOT NULL,
  price                       NUMERIC(10, 2)    NOT NULL CHECK (price >= 0),

  main_image_url              TEXT,
  additional_images           TEXT[]            NOT NULL DEFAULT '{}',

  ingredients                 TEXT[]            NOT NULL DEFAULT '{}',
  allergens                   TEXT[]            NOT NULL DEFAULT '{}',
  nutritional_info            JSONB,
  labels                      TEXT[]            NOT NULL DEFAULT '{}',

  sizes                       JSONB             NOT NULL DEFAULT '[]'::jsonb,
  options                     JSONB             NOT NULL DEFAULT '[]'::jsonb,
  allowed_modifications       TEXT[]            NOT NULL DEFAULT '{}',

  is_available                BOOLEAN           NOT NULL DEFAULT TRUE,
  stock_quantity              INTEGER,
  estimated_preparation_time  SMALLINT          NOT NULL DEFAULT 15,

  is_seasonal                 BOOLEAN           NOT NULL DEFAULT FALSE,
  available_from              TIMESTAMPTZ,
  available_until             TIMESTAMPTZ,

  order_count                 INTEGER           NOT NULL DEFAULT 0,
  rating                      DOUBLE PRECISION,

  created_at                  TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS products_restaurant_idx ON wintime.products(restaurant_id);
CREATE INDEX IF NOT EXISTS products_category_avail_idx
  ON wintime.products(category_id, is_available);

-- ─── 5. orders ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wintime.orders (
  id                          UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number                TEXT              NOT NULL,

  restaurant_id               UUID              NOT NULL REFERENCES wintime.restaurants(id),
  customer_id                 UUID              NOT NULL REFERENCES auth.users(id),

  -- Snapshot des infos client (figé à la création, pas une FK live)
  customer_info               JSONB,

  -- Snapshot des items (productId/name/price figés au moment de la commande)
  items                       JSONB             NOT NULL,

  subtotal                    NUMERIC(10, 2)    NOT NULL,
  tax_amount                  NUMERIC(10, 2)    NOT NULL,
  total_amount                NUMERIC(10, 2)    NOT NULL,
  commission_amount           NUMERIC(10, 2),

  status                      TEXT              NOT NULL CHECK (
    status IN ('pending', 'accepted', 'preparing', 'ready', 'completed', 'cancelled', 'rejected')
  ),
  payment_status              TEXT              NOT NULL CHECK (
    payment_status IN ('pending', 'paid', 'failed', 'refunded')
  ),
  payment_method              TEXT              NOT NULL,

  scheduled_pickup_time       TIMESTAMPTZ,
  accepted_at                 TIMESTAMPTZ,
  ready_at                    TIMESTAMPTZ,
  completed_at                TIMESTAMPTZ,
  cancelled_at                TIMESTAMPTZ,

  estimated_preparation_time  SMALLINT          NOT NULL,
  actual_preparation_time     SMALLINT,

  special_instructions        TEXT,
  cancellation_reason         TEXT,

  is_paid                     BOOLEAN           NOT NULL DEFAULT FALSE,
  is_rated                    BOOLEAN           NOT NULL DEFAULT FALSE,
  rating                      DOUBLE PRECISION,
  review                      TEXT,

  created_at                  TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

-- Index actives pour le Pro dashboard
CREATE INDEX IF NOT EXISTS orders_restaurant_active_idx
  ON wintime.orders(restaurant_id, status, created_at DESC);

-- Index historique customer
CREATE INDEX IF NOT EXISTS orders_customer_idx
  ON wintime.orders(customer_id, created_at DESC);

-- ─── 6. Trigger updated_at automatique ────────────────────────────────────
CREATE OR REPLACE FUNCTION wintime.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS user_profiles_set_updated_at ON wintime.user_profiles;
DROP TRIGGER IF EXISTS restaurants_set_updated_at  ON wintime.restaurants;
DROP TRIGGER IF EXISTS categories_set_updated_at   ON wintime.categories;
DROP TRIGGER IF EXISTS products_set_updated_at     ON wintime.products;
DROP TRIGGER IF EXISTS orders_set_updated_at       ON wintime.orders;

-- (user_profiles n'a pas de updated_at, skip)
CREATE TRIGGER restaurants_set_updated_at
  BEFORE UPDATE ON wintime.restaurants
  FOR EACH ROW EXECUTE FUNCTION wintime.set_updated_at();
CREATE TRIGGER categories_set_updated_at
  BEFORE UPDATE ON wintime.categories
  FOR EACH ROW EXECUTE FUNCTION wintime.set_updated_at();
CREATE TRIGGER products_set_updated_at
  BEFORE UPDATE ON wintime.products
  FOR EACH ROW EXECUTE FUNCTION wintime.set_updated_at();
CREATE TRIGGER orders_set_updated_at
  BEFORE UPDATE ON wintime.orders
  FOR EACH ROW EXECUTE FUNCTION wintime.set_updated_at();

-- ─── 7. Realtime publication ──────────────────────────────────────────────
-- Active la propagation des changements vers les listeners Supabase Realtime
-- (utilisé par le Pro dashboard pour voir les nouvelles commandes en live et
-- par le Client pour le tracking de sa commande).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    -- Idempotent : ALTER PUBLICATION ... ADD TABLE échoue si déjà ajoutée
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE wintime.orders;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE wintime.restaurants;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE wintime.products;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE wintime.categories;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

-- ─── 8. Permissions PostgREST ─────────────────────────────────────────────
-- PostgREST utilise les rôles `anon` (anon key) et `authenticated` (logged-in
-- via JWT). Sans GRANT, RLS bloque même les reads autorisés.
GRANT USAGE ON SCHEMA wintime TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA wintime TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA wintime TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA wintime TO service_role;

-- Tables futures héritent des grants
ALTER DEFAULT PRIVILEGES IN SCHEMA wintime
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA wintime
  GRANT SELECT ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA wintime
  GRANT ALL ON TABLES TO service_role;
