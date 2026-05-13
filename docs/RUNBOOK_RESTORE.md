# Win Time — DR Runbook: Restore from R2 backup

Audit refs: S6.2.1 (no documented backup), S12.3.8 (DR tabletop catastrophic).

## RTO / RPO target

- **RTO 4 hours** (time to back online)
- **RPO 24 hours** (max data loss = latest nightly backup)

Anything stricter requires WAL archiving / PITR which is a Sprint 2 item.

## Required credentials (out-of-band — NOT in the repo)

- SSH key for the VPS hosting `supabase.0for0.com`
- Cloudflare R2 access (`R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY`, bucket `wintime-backups`)
- Postgres `postgres` user password on the host (read from `docker exec supabase-db env | grep POSTGRES_PASSWORD`)
- A spare Hetzner / OVH VPS account ready to provision a replacement host

## Scenario A — Data corruption, host healthy

```bash
# 1. Pull yesterday's backup from R2
aws s3 ls s3://wintime-backups/wintime/$(date -u +%Y/%m/) \
  --endpoint-url "$R2_ENDPOINT" --recursive | tail -3
aws s3 cp s3://wintime-backups/wintime/<yyyy>/<mm>/<dd>/wintime-<stamp>.pgcustom.gz /tmp/ \
  --endpoint-url "$R2_ENDPOINT"

# 2. Decompress
gunzip /tmp/wintime-<stamp>.pgcustom.gz

# 3. Drop the broken schema (back up first if anything salvageable remains)
docker exec supabase-db pg_dump -U postgres -d postgres -n wintime \
  -F custom -f /tmp/wintime-pre-restore.pgcustom postgres
docker exec supabase-db psql -U postgres -d postgres -c "DROP SCHEMA wintime CASCADE;"

# 4. Restore
docker cp /tmp/wintime-<stamp>.pgcustom supabase-db:/tmp/restore.pgcustom
docker exec supabase-db pg_restore -U postgres -d postgres /tmp/restore.pgcustom

# 5. Smoke-test
docker exec supabase-db psql -U postgres -d postgres \
  -c "SELECT count(*) FROM wintime.restaurants;"
```

## Scenario B — VPS dead, must rebuild from scratch

```bash
# 1. Provision a fresh VPS (Hetzner CCX, Debian 12, 4 GB RAM minimum)
# 2. Install Docker + docker-compose
# 3. Bring up Supabase self-hosted (see https://supabase.com/docs/guides/self-hosting)
# 4. Apply migrations in order
for f in migrations/20260504_*.sql migrations/20260513_*.sql; do
  docker cp "$f" supabase-db:/tmp/$(basename "$f")
  docker exec supabase-db psql -U postgres -d postgres -f "/tmp/$(basename "$f")"
done
# 5. Restore latest backup as in Scenario A from step 1
# 6. Point DNS for supabase.0for0.com at the new IP
# 7. Verify by running the cURL probe in SETUP_SUPABASE.md §7
```

## Scenario C — Accidental data loss in a single table

Use the backup as a side-load:

```bash
# Restore the single table into a sandbox database
docker exec supabase-db createdb -U postgres restore_sandbox
docker exec supabase-db pg_restore -U postgres -d restore_sandbox \
  -n wintime -t orders /tmp/wintime-<stamp>.pgcustom

# Inspect → cherry-pick rows you need → INSERT back into the live DB
docker exec -it supabase-db psql -U postgres restore_sandbox
```

## After every restore — verify

1. `SELECT count(*)` on every table matches the previous snapshot ±expected delta.
2. The realtime publication still contains `orders`, `restaurants`, `products`, `categories`:
   ```sql
   SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
   ```
3. RLS policies are still enabled:
   ```sql
   SELECT relname, relrowsecurity FROM pg_class
   WHERE relkind = 'r' AND relnamespace = 'wintime'::regnamespace;
   -- relrowsecurity must be 't' for all five tables
   ```
4. The sequence state for invoice + order numbers is intact:
   ```sql
   SELECT * FROM wintime.invoice_number_seq;
   SELECT * FROM wintime.order_number_seq;
   ```
5. Both apps connect (manual: log in as `owner.demo@wintime.test` on Client and on Pro).

## Monthly drill (do this — don't skip)

On the 1st of each month: download the latest backup to a laptop, run Scenario A locally with Docker. If it doesn't work, it isn't a backup — it's a wish.
