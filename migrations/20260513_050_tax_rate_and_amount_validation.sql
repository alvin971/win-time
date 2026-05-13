-- ============================================================================
-- Win Time — Per-product VAT (TVA) + server-side order amount validation
-- Date    : 2026-05-13
-- Audit refs: S2.2.1 (client-controlled prices), S2.2.11 (10% hardcoded
--   TVA is wrong), S12.3.2 (CGI 279 m bis: 5.5% take-away / 10% sit-in /
--   20% alcohol), S2.2.6 (state machine + server-side stamping).
--
-- WHY: today the client INSERTs an order with whatever subtotal/tax/total it
-- chose; the database has no idea what's correct. This migration adds the
-- per-product `tax_rate`, an `items_total_cents`/`tax_total_cents` server-side
-- recompute, and a trigger that refuses inserts where the client-supplied
-- amounts diverge from the server-side recompute by more than 1 cent.
--
-- IDEMPOTENT.
-- ============================================================================

-- ─── 1. tax_rate on products ────────────────────────────────────────────────
-- CHECK constrains to French rate bands. 5.5% take-away, 10% sit-in, 20%
-- alcohol. 0% is legal for some edge cases (e.g. gift cards).
ALTER TABLE wintime.products
  ADD COLUMN IF NOT EXISTS tax_rate NUMERIC(5, 4) NOT NULL DEFAULT 0.0550
    CHECK (tax_rate IN (0.0000, 0.0550, 0.1000, 0.2000));

COMMENT ON COLUMN wintime.products.tax_rate IS
  'French VAT rate per CGI article 279 m bis: 0.055 take-away ready-to-eat (default), 0.10 sit-down service, 0.20 alcohol. Override per product.';

-- ─── 2. tax_breakdown on orders (per-rate detail kept for invoicing) ────────
ALTER TABLE wintime.orders
  ADD COLUMN IF NOT EXISTS tax_breakdown JSONB
    NOT NULL DEFAULT '[]'::jsonb;
-- Shape: [{"rate": "0.0550", "base_ht": 1234, "tax": 68}, ...]  (amounts in cents)

COMMENT ON COLUMN wintime.orders.tax_breakdown IS
  'Per-VAT-rate breakdown computed server-side on insert. Amounts in cents to avoid FP error.';

-- ─── 3. Server-side recompute + amount validation trigger ───────────────────
-- The trigger:
--   1. Walks the items JSONB array
--   2. Looks up each product's price + tax_rate from wintime.products
--   3. Recomputes subtotal / tax / total in CENTS (no FP error)
--   4. Stores the canonical recompute in subtotal/tax_amount/total_amount/tax_breakdown
--   5. Rejects insert if the client-supplied total diverges from server total
--      by more than 1 cent (rounding tolerance only)
--
-- This is BEFORE INSERT only — once an order is in pending, the orders_owner_update
-- policy + state-machine trigger handle subsequent UPDATEs. We don't allow line-item
-- mutation after creation.

CREATE OR REPLACE FUNCTION wintime.recompute_and_validate_order_amounts()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  item              JSONB;
  product_row       wintime.products%ROWTYPE;
  qty               INTEGER;
  unit_price_cents  INTEGER;
  line_total_cents  INTEGER;
  rate              NUMERIC(5,4);
  rate_text         TEXT;

  subtotal_cents    BIGINT := 0;
  tax_cents         BIGINT := 0;
  per_rate_cents    JSONB  := '{}'::jsonb;
  rate_row          JSONB;

  client_total_cents BIGINT;
  server_total_cents BIGINT;
BEGIN
  IF jsonb_array_length(NEW.items) = 0 THEN
    RAISE EXCEPTION 'order has no items';
  END IF;

  FOR item IN SELECT jsonb_array_elements(NEW.items)
  LOOP
    SELECT * INTO product_row
    FROM wintime.products
    WHERE id = (item->>'productId')::UUID;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'unknown productId %', item->>'productId';
    END IF;

    IF product_row.restaurant_id <> NEW.restaurant_id THEN
      RAISE EXCEPTION 'productId % belongs to a different restaurant', product_row.id;
    END IF;

    IF NOT product_row.is_available THEN
      RAISE EXCEPTION 'productId % is not available', product_row.id;
    END IF;

    qty := COALESCE((item->>'quantity')::INTEGER, 0);
    IF qty <= 0 OR qty > 100 THEN
      RAISE EXCEPTION 'illegal quantity % for productId %', qty, product_row.id;
    END IF;

    unit_price_cents := ROUND(product_row.price * 100)::INTEGER;
    line_total_cents := unit_price_cents * qty;
    rate := product_row.tax_rate;
    rate_text := rate::TEXT;

    subtotal_cents := subtotal_cents + line_total_cents;
    tax_cents      := tax_cents + ROUND(line_total_cents * rate)::INTEGER;

    -- Accumulate per-rate breakdown
    rate_row := COALESCE(per_rate_cents -> rate_text,
                        jsonb_build_object('rate', rate_text, 'base_ht', 0, 'tax', 0));
    rate_row := jsonb_set(rate_row, '{base_ht}',
                          to_jsonb((rate_row->>'base_ht')::BIGINT + line_total_cents));
    rate_row := jsonb_set(rate_row, '{tax}',
                          to_jsonb((rate_row->>'tax')::BIGINT + ROUND(line_total_cents * rate)::BIGINT));
    per_rate_cents := jsonb_set(per_rate_cents, ARRAY[rate_text], rate_row);
  END LOOP;

  server_total_cents := subtotal_cents + tax_cents;
  client_total_cents := ROUND(NEW.total_amount * 100)::BIGINT;

  -- 1-cent tolerance for rounding differences. Anything bigger = client is wrong/malicious.
  IF ABS(server_total_cents - client_total_cents) > 1 THEN
    RAISE EXCEPTION 'order total mismatch: client said %, server computed % (cents)',
      client_total_cents, server_total_cents;
  END IF;

  -- Overwrite client-supplied amounts with the server-canonical ones.
  NEW.subtotal      := subtotal_cents / 100.0;
  NEW.tax_amount    := tax_cents / 100.0;
  NEW.total_amount  := server_total_cents / 100.0;
  NEW.tax_breakdown := (SELECT jsonb_agg(value) FROM jsonb_each(per_rate_cents));

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS orders_validate_amounts ON wintime.orders;
CREATE TRIGGER orders_validate_amounts
  BEFORE INSERT ON wintime.orders
  FOR EACH ROW
  EXECUTE FUNCTION wintime.recompute_and_validate_order_amounts();


-- ─── 4. Server-side order_number generation (idempotency) ───────────────────
-- Today the client builds `WT-{millis}` and races on collision under load.
-- Add a per-restaurant per-year sequence.

CREATE TABLE IF NOT EXISTS wintime.order_number_seq (
  restaurant_id UUID    NOT NULL,
  fiscal_year   INTEGER NOT NULL,
  next_value    INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (restaurant_id, fiscal_year)
);

CREATE OR REPLACE FUNCTION wintime.next_order_number(rest_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  year INT := EXTRACT(YEAR FROM NOW())::INT;
  v    INT;
BEGIN
  INSERT INTO wintime.order_number_seq (restaurant_id, fiscal_year, next_value)
  VALUES (rest_id, year, 2)
  ON CONFLICT (restaurant_id, fiscal_year)
  DO UPDATE SET next_value = wintime.order_number_seq.next_value + 1
  RETURNING next_value - 1 INTO v;

  -- Format: WT-2026-000123 — short, year-prefixed, monotonic per restaurant.
  RETURN format('WT-%s-%s', year, LPAD(v::TEXT, 6, '0'));
END;
$$;

-- The client may still set order_number client-side for legacy compatibility;
-- if it's blank or "WT-…" format we replace it. This avoids breaking the
-- recent commit that fixed JSONB camelCase issues; the change is opt-in.
CREATE OR REPLACE FUNCTION wintime.fill_order_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.order_number IS NULL
     OR NEW.order_number = ''
     OR NEW.order_number ~ '^WT-[0-9]+$' THEN
    NEW.order_number := wintime.next_order_number(NEW.restaurant_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS orders_fill_order_number ON wintime.orders;
CREATE TRIGGER orders_fill_order_number
  BEFORE INSERT ON wintime.orders
  FOR EACH ROW
  EXECUTE FUNCTION wintime.fill_order_number();

GRANT SELECT, INSERT, UPDATE ON wintime.order_number_seq TO authenticated;
