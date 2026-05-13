-- ============================================================================
-- ROLLBACK: 20260504_010_wintime_schema.sql
-- DANGER: this drops the entire `wintime` schema. All restaurant + customer
-- + order data is lost. Use only when fully resetting an environment.
--
-- Recommended preflight (replace `localhost`):
--   docker exec supabase-db pg_dump -U postgres -n wintime -F custom -f /tmp/wintime-pre-rollback.pgcustom postgres
-- ============================================================================

-- Remove Realtime publication entries (idempotent).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN ALTER PUBLICATION supabase_realtime DROP TABLE wintime.orders;      EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime DROP TABLE wintime.restaurants; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime DROP TABLE wintime.products;    EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime DROP TABLE wintime.categories;  EXCEPTION WHEN OTHERS THEN NULL; END;
  END IF;
END $$;

DROP SCHEMA IF EXISTS wintime CASCADE;
