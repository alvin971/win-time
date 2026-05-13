#!/usr/bin/env bash
# scripts/backup_wintime.sh
# ----------------------------------------------------------------------------
# Nightly pg_dump of the `wintime` schema → gzip → upload to Cloudflare R2 via
# the AWS-compatible S3 API. Designed to run on the VPS that hosts
# supabase.0for0.com, scheduled by cron.
#
# REQUIRES (set in /etc/wintime-backup.env, root-owned 600):
#   R2_ENDPOINT       e.g. https://<accountid>.r2.cloudflarestorage.com
#   R2_BUCKET         e.g. wintime-backups
#   R2_ACCESS_KEY_ID
#   R2_SECRET_ACCESS_KEY
#   POSTGRES_CONTAINER  default: supabase-db
#   RETENTION_DAYS    default: 30
#
# CRON LINE (root crontab — 02:30 UTC every day):
#   30 2 * * *  /home/ubuntu/win-time/scripts/backup_wintime.sh >> /var/log/wintime-backup.log 2>&1
#
# RESTORE (manual procedure documented in docs/RUNBOOK_RESTORE.md):
#   pg_restore -d postgres -F custom /tmp/wintime-YYYYMMDD.pgcustom
# ----------------------------------------------------------------------------

set -euo pipefail

ENV_FILE="${WINTIME_BACKUP_ENV:-/etc/wintime-backup.env}"
if [[ ! -r "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found or not readable" >&2
  exit 2
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${R2_ENDPOINT:?missing}"
: "${R2_BUCKET:?missing}"
: "${R2_ACCESS_KEY_ID:?missing}"
: "${R2_SECRET_ACCESS_KEY:?missing}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-supabase-db}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

DUMP="$TMP_DIR/wintime-$STAMP.pgcustom"
DUMP_GZ="$DUMP.gz"

echo "[$(date -u +%FT%TZ)] Starting backup of schema 'wintime' from container $POSTGRES_CONTAINER"

# Custom format is compressible *and* selective-restore-able. We also dump
# the wintime.invoice_number_seq + wintime.order_number_seq tables which
# carry the L441-9 sequence state.
docker exec "$POSTGRES_CONTAINER" pg_dump \
  -U postgres \
  -d postgres \
  -n wintime \
  -F custom \
  --no-owner \
  --no-acl \
  -f "/tmp/wintime-$STAMP.pgcustom"

docker cp "$POSTGRES_CONTAINER:/tmp/wintime-$STAMP.pgcustom" "$DUMP"
docker exec "$POSTGRES_CONTAINER" rm -f "/tmp/wintime-$STAMP.pgcustom"

SIZE=$(stat -c '%s' "$DUMP")
echo "[$(date -u +%FT%TZ)] pg_dump complete: $SIZE bytes"

gzip -9 "$DUMP"

# Compute MD5 for Content-MD5 header (R2 supports it).
MD5_B64="$(openssl dgst -md5 -binary "$DUMP_GZ" | base64)"

OBJECT_KEY="wintime/$(date -u +%Y/%m/%d)/wintime-$STAMP.pgcustom.gz"
URL="$R2_ENDPOINT/$R2_BUCKET/$OBJECT_KEY"

# AWS Signature V4 via aws-cli is the most reliable way. Falls back to s3cmd
# if aws-cli isn't installed. Either tool reads R2_ACCESS_KEY_ID via env.
if command -v aws >/dev/null 2>&1; then
  AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
  AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
  AWS_DEFAULT_REGION="auto" \
  aws s3 cp "$DUMP_GZ" "s3://$R2_BUCKET/$OBJECT_KEY" --endpoint-url "$R2_ENDPOINT"
else
  echo "ERROR: aws-cli not installed. Install with: apt-get install -y awscli" >&2
  exit 3
fi

echo "[$(date -u +%FT%TZ)] Upload complete: $OBJECT_KEY"

# Retention sweep — delete objects older than RETENTION_DAYS days.
CUTOFF_DATE=$(date -u -d "$RETENTION_DAYS days ago" +%Y-%m-%d)
echo "[$(date -u +%FT%TZ)] Sweeping objects older than $CUTOFF_DATE"

AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
AWS_DEFAULT_REGION="auto" \
aws s3 ls "s3://$R2_BUCKET/wintime/" --recursive --endpoint-url "$R2_ENDPOINT" \
  | awk -v cutoff="$CUTOFF_DATE" '$1 < cutoff {print $4}' \
  | while read -r oldkey; do
      echo "  deleting s3://$R2_BUCKET/$oldkey"
      AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
      AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
      AWS_DEFAULT_REGION="auto" \
      aws s3 rm "s3://$R2_BUCKET/$oldkey" --endpoint-url "$R2_ENDPOINT" >/dev/null
    done

echo "[$(date -u +%FT%TZ)] Done."
