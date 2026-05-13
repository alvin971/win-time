-- ============================================================================
-- Win Time — French legal columns (SIRET, TVA, RCS) + L441-9 invoice numbering
-- Date    : 2026-05-13
-- Audit refs: S12.3.3 (Code de commerce L441-9: sequential invoice numbers),
--   S12.3.5 (SIRET / TVA / RCS / legal_form / capital_social required for
--   invoicing on behalf of French restaurants).
--
-- IDEMPOTENT.
-- ============================================================================

-- ─── 1. Legal columns on wintime.restaurants ────────────────────────────────
-- All optional at the schema level so existing restaurants don't break; the
-- Pro app's "complete your profile" wizard makes them required UX-side before
-- the restaurant can flip is_approved=TRUE.

ALTER TABLE wintime.restaurants
  ADD COLUMN IF NOT EXISTS siret                TEXT,
  ADD COLUMN IF NOT EXISTS tva_intracommunautaire TEXT,
  ADD COLUMN IF NOT EXISTS legal_form           TEXT,
  ADD COLUMN IF NOT EXISTS rcs_number           TEXT,
  ADD COLUMN IF NOT EXISTS capital_social_cents BIGINT;

-- SIRET = 14 digits (SIREN 9 + NIC 5). Enforced shape; the LUHN checksum
-- is enforced in the application layer to keep the SQL simple.
ALTER TABLE wintime.restaurants
  DROP CONSTRAINT IF EXISTS restaurants_siret_format;
ALTER TABLE wintime.restaurants
  ADD CONSTRAINT restaurants_siret_format
  CHECK (siret IS NULL OR siret ~ '^[0-9]{14}$');

-- French intra-EU VAT number: 'FR' + 2 control digits + 9-digit SIREN.
ALTER TABLE wintime.restaurants
  DROP CONSTRAINT IF EXISTS restaurants_tva_format;
ALTER TABLE wintime.restaurants
  ADD CONSTRAINT restaurants_tva_format
  CHECK (tva_intracommunautaire IS NULL OR tva_intracommunautaire ~ '^FR[0-9A-Z]{2}[0-9]{9}$');

-- Legal forms permitted in the dropdown.
ALTER TABLE wintime.restaurants
  DROP CONSTRAINT IF EXISTS restaurants_legal_form;
ALTER TABLE wintime.restaurants
  ADD CONSTRAINT restaurants_legal_form
  CHECK (legal_form IS NULL OR legal_form IN (
    'micro-entreprise',
    'EI',
    'EIRL',
    'EURL',
    'SARL',
    'SAS',
    'SASU',
    'SA',
    'SNC',
    'autre'
  ));

COMMENT ON COLUMN wintime.restaurants.siret IS
  'SIRET = SIREN(9) + NIC(5). Required for invoicing per Code commerce L441-9.';
COMMENT ON COLUMN wintime.restaurants.tva_intracommunautaire IS
  'Intra-EU VAT number FR + checksum + SIREN. Optional (micro-entreprises VAT-exempt under threshold).';


-- ─── 2. invoice_number on orders — L441-9 compliant ─────────────────────────
-- Sequential per restaurant per fiscal year, no gaps. Generated server-side.

ALTER TABLE wintime.orders
  ADD COLUMN IF NOT EXISTS invoice_number TEXT;

-- Unique within a (restaurant, year) — uniqueness alone doesn't prove
-- "no gaps" but combined with the trigger-driven sequence it does.
CREATE UNIQUE INDEX IF NOT EXISTS orders_invoice_number_uniq
  ON wintime.orders(restaurant_id, invoice_number)
  WHERE invoice_number IS NOT NULL;

CREATE TABLE IF NOT EXISTS wintime.invoice_number_seq (
  restaurant_id UUID    NOT NULL,
  fiscal_year   INTEGER NOT NULL,
  next_value    INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (restaurant_id, fiscal_year)
);

CREATE OR REPLACE FUNCTION wintime.next_invoice_number(rest_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  year INT := EXTRACT(YEAR FROM NOW())::INT;
  v    INT;
BEGIN
  INSERT INTO wintime.invoice_number_seq (restaurant_id, fiscal_year, next_value)
  VALUES (rest_id, year, 2)
  ON CONFLICT (restaurant_id, fiscal_year)
  DO UPDATE SET next_value = wintime.invoice_number_seq.next_value + 1
  RETURNING next_value - 1 INTO v;

  -- Format: FAC-2026-000001 — restaurateur-facing.
  RETURN format('FAC-%s-%s', year, LPAD(v::TEXT, 6, '0'));
END;
$$;

-- Generate the invoice number the moment the order becomes 'completed'.
-- A 'cancelled' or 'rejected' order does NOT get an invoice number — that
-- preserves the L441-9 "no gaps for accepted operations" rule.
CREATE OR REPLACE FUNCTION wintime.fill_invoice_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'completed'
     AND OLD.status <> 'completed'
     AND NEW.invoice_number IS NULL THEN
    NEW.invoice_number := wintime.next_invoice_number(NEW.restaurant_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS orders_fill_invoice_number ON wintime.orders;
CREATE TRIGGER orders_fill_invoice_number
  BEFORE UPDATE OF status ON wintime.orders
  FOR EACH ROW
  EXECUTE FUNCTION wintime.fill_invoice_number();

GRANT SELECT, INSERT, UPDATE ON wintime.invoice_number_seq TO authenticated;
