-- ============================================================================
-- ROLLBACK: 20260513_050_tax_rate_and_amount_validation.sql
-- ============================================================================

DROP TRIGGER  IF EXISTS orders_fill_order_number    ON wintime.orders;
DROP TRIGGER  IF EXISTS orders_validate_amounts     ON wintime.orders;
DROP FUNCTION IF EXISTS wintime.fill_order_number();
DROP FUNCTION IF EXISTS wintime.next_order_number(UUID);
DROP FUNCTION IF EXISTS wintime.recompute_and_validate_order_amounts();
DROP TABLE    IF EXISTS wintime.order_number_seq;

ALTER TABLE wintime.orders   DROP COLUMN IF EXISTS tax_breakdown;
ALTER TABLE wintime.products DROP COLUMN IF EXISTS tax_rate;
