-- ROLLBACK: 20260513_070_pickup_codes_and_stripe.sql

DROP VIEW   IF EXISTS wintime.my_restaurants;
DROP TABLE  IF EXISTS wintime.restaurant_members;
DROP TRIGGER IF EXISTS orders_gen_pickup_code ON wintime.orders;
DROP FUNCTION IF EXISTS wintime.gen_pickup_code();
DROP INDEX  IF EXISTS wintime.orders_stripe_pi_uniq;
DROP INDEX  IF EXISTS wintime.restaurants_stripe_account_uniq;
ALTER TABLE wintime.orders      DROP COLUMN IF EXISTS pickup_code;
ALTER TABLE wintime.orders      DROP COLUMN IF EXISTS stripe_payment_intent_id;
ALTER TABLE wintime.orders      DROP COLUMN IF EXISTS stripe_charge_id;
ALTER TABLE wintime.orders      DROP COLUMN IF EXISTS payment_captured_at;
ALTER TABLE wintime.orders      DROP COLUMN IF EXISTS saved_vs_aggregator_cents;
ALTER TABLE wintime.restaurants DROP COLUMN IF EXISTS stripe_account_id;
ALTER TABLE wintime.restaurants DROP COLUMN IF EXISTS stripe_charges_enabled;
ALTER TABLE wintime.restaurants DROP COLUMN IF EXISTS stripe_payouts_enabled;
ALTER TABLE wintime.restaurants DROP COLUMN IF EXISTS stripe_details_submitted_at;
