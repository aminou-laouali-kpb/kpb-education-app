#!/usr/bin/env bash
# Read-only proof that the automated backup service is running and its newest
# archive is recent and structurally readable. No database connection is made.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups}"
BACKUP_FILE="${BACKUP_FILE:-}"
MAX_AGE_SECONDS="${MAX_AGE_SECONDS:-108000}" # 30 hours for a daily backup
MIN_BYTES="${MIN_BYTES:-1024}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
CHECK_SERVICE="${CHECK_BACKUP_SERVICE:-true}"

case "$MAX_AGE_SECONDS:$MIN_BYTES" in
  *[!0-9:]*|:*|*:) echo "error: age and size limits must be non-negative integers" >&2; exit 2 ;;
esac
[ -d "$BACKUP_DIR" ] || { echo "error: backup directory not found: $BACKUP_DIR" >&2; exit 1; }

if [ "$CHECK_SERVICE" = "true" ]; then
  command -v docker >/dev/null || { echo "error: docker is required to inspect db-backup" >&2; exit 1; }
  service_id="$(docker compose -f "$COMPOSE_FILE" ps -q db-backup 2>/dev/null || true)"
  [ -n "$service_id" ] || { echo "error: db-backup service is not created" >&2; exit 1; }
  service_state="$(docker inspect --format '{{.State.Status}}' "$service_id")"
  [ "$service_state" = "running" ] || {
    echo "error: db-backup service state is '$service_state', expected running" >&2
    exit 1
  }
fi

if [ -n "$BACKUP_FILE" ]; then
  newest="$BACKUP_FILE"
else
  newest="$(find "$BACKUP_DIR" -maxdepth 1 -type f \
    \( -name 'kpb-*.sql.gz' -o -name 'predeploy-*.dump' \) \
    -print0 | xargs -0 -r ls -1t | head -1 || true)"
fi
[ -n "$newest" ] || { echo "error: no supported database backup found in $BACKUP_DIR" >&2; exit 1; }
[ -f "$newest" ] || { echo "error: backup file not found: $newest" >&2; exit 1; }

bytes="$(wc -c < "$newest" | tr -d ' ')"
[ "$bytes" -ge "$MIN_BYTES" ] || {
  echo "error: newest backup is only ${bytes} bytes (minimum ${MIN_BYTES}): $newest" >&2
  exit 1
}

mtime="$(stat -c %Y "$newest" 2>/dev/null || stat -f %m "$newest")"
now="$(date +%s)"
age=$((now - mtime))
[ "$age" -ge 0 ] || { echo "error: backup timestamp is in the future: $newest" >&2; exit 1; }
[ "$age" -le "$MAX_AGE_SECONDS" ] || {
  echo "error: newest backup is ${age}s old (maximum ${MAX_AGE_SECONDS}s): $newest" >&2
  exit 1
}

case "$newest" in
  *.sql.gz)
    gzip -t "$newest"
    # `gzip -t` accepte un flux tronqué proprement fermé : on exige aussi le
    # marqueur final que pg_dump écrit en fin de dump texte.
    gzip -dc "$newest" | tail -n 5 | grep 'PostgreSQL database dump complete' >/dev/null || {
      echo "error: plain dump is truncated (no completion marker): $newest" >&2
      exit 1
    }
    ;;
  *.dump)
    magic="$(LC_ALL=C head -c 5 "$newest")"
    [ "$magic" = "PGDMP" ] || { echo "error: custom dump has invalid header: $newest" >&2; exit 1; }
    ;;
esac

echo "backup_service=${service_state:-not-checked}"
echo "backup_file=$(basename "$newest")"
echo "backup_bytes=$bytes"
echo "backup_age_seconds=$age"
echo "BACKUP FRESHNESS OK"
