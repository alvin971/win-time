-- ============================================================================
-- ROLLBACK: 20260513_060_french_legal_columns.sql
-- ============================================================================

DROP TRIGGER  IF EXISTS orders_fill_invoice_number ON wintime.orders;
DROP FUNCTION IF EXISTS wintime.fill_invoice_number();
DROP FUNCTION IF EXISTS wintime.next_invoice_number(UUID);
DROP TABLE    IF EXISTS wintime.invoice_number_seq;
DROP INDEX    IF EXISTS wintime.orders_invoice_number_uniq;

ALTER TABLE wintime.orders      DROP COLUMN IF EXISTS invoice_number;
ALTER TABLE wintime.restaurants DROP CONSTRAINT IF EXISTS restaurants_siret_format;
ALTER TABLE wintime.restaurants DROP CONSTRAINT IF EXISTS restaurants_tva_format;
ALTER TABLE wintime.restaurants DROP CONSTRAINT IF EXISTS restaurants_legal_form;
ALTER TABLE wintime.restaurants
  DROP COLUMN IF EXISTS siret,
  DROP COLUMN IF EXISTS tva_intracommunautaire,
  DROP COLUMN IF EXISTS legal_form,
  DROP COLUMN IF EXISTS rcs_number,
  DROP COLUMN IF EXISTS capital_social_cents;
