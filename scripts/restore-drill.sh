#!/usr/bin/env bash
# Restore a production backup into a disposable PostgreSQL container.
# The default is a read-only plan. Pass --execute to create an isolated Docker
# volume/container; the production database/container is never referenced.
set -euo pipefail

EXECUTE=false
DUMP_FILE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --execute) EXECUTE=true ;;
    --dump) shift; DUMP_FILE="${1:?--dump requires a path}" ;;
    -h|--help)
      echo "usage: $0 [--execute] [--dump PATH]"
      exit 0
      ;;
    *) echo "error: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

BACKUP_DIR="${BACKUP_DIR:-./backups}"
MAX_AGE_SECONDS="${MAX_AGE_SECONDS:-108000}"
if [ -z "$DUMP_FILE" ]; then
  DUMP_FILE="$(find "$BACKUP_DIR" -maxdepth 1 -type f \
    \( -name 'kpb-*.sql.gz' -o -name 'predeploy-*.dump' \) \
    -print0 | xargs -0 -r ls -1t | head -1 || true)"
fi
[ -n "$DUMP_FILE" ] && [ -f "$DUMP_FILE" ] || {
  echo "error: no restore candidate found" >&2
  exit 1
}

# Structural/freshness validation is shared with the scheduled backup gate.
CHECK_BACKUP_SERVICE=false BACKUP_DIR="$(dirname "$DUMP_FILE")" \
  BACKUP_FILE="$DUMP_FILE" \
  MAX_AGE_SECONDS="$MAX_AGE_SECONDS" MIN_BYTES="${MIN_BYTES:-1024}" \
  "$(dirname "$0")/check-backup-freshness.sh"

echo "restore_candidate=$DUMP_FILE"
if [ "$EXECUTE" != "true" ]; then
  echo "DRY RUN: no container, volume, database, or file was changed."
  echo "Re-run with --execute to restore into a disposable isolated PostgreSQL container."
  exit 0
fi

command -v docker >/dev/null || { echo "error: docker is required" >&2; exit 1; }
suffix="$(date -u +%Y%m%d%H%M%S)-$$"
container="kpb-restore-drill-${suffix}"
volume="kpb-restore-drill-${suffix}"
password="drill-${suffix}-local-only"

cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
  docker volume rm "$volume" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker volume create "$volume" >/dev/null
docker run -d --name "$container" --network none \
  --memory 1g --cpus 2 --pids-limit 256 \
  -e POSTGRES_PASSWORD="$password" -e POSTGRES_DB=kpb_restore_drill \
  -v "$volume:/var/lib/postgresql/data" postgres:15-alpine >/dev/null

ready=0
for _ in $(seq 1 30); do
  if docker exec "$container" pg_isready -U postgres -d kpb_restore_drill >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
[ "$ready" = "1" ] || { echo "error: disposable PostgreSQL did not become ready" >&2; exit 1; }

# Le chemin réel de restauration (backend/scripts/restore-db.sh) est exercé
# quand il est présent (exécution depuis la racine du dépôt sur le VPS), et
# DEUX fois : la seconde passe restaure par-dessus une base déjà peuplée, le
# cas d'un incident, qu'une restauration dans une base vide ne prouvait pas.
# Le workflow passe RESTORE_DB_SCRIPT (copie de la révision testée) : s'il est
# posé mais introuvable, c'est une erreur, pas un repli silencieux.
if [ -n "${RESTORE_DB_SCRIPT:-}" ] && [ ! -f "$RESTORE_DB_SCRIPT" ]; then
  echo "error: RESTORE_DB_SCRIPT not found: $RESTORE_DB_SCRIPT" >&2
  exit 1
fi
RESTORE_DB_SCRIPT="${RESTORE_DB_SCRIPT:-backend/scripts/restore-db.sh}"
if [ -f "$RESTORE_DB_SCRIPT" ]; then
  for pass in 1 2; do
    POSTGRES_USER=postgres POSTGRES_DB=kpb_restore_drill DB_CONTAINER="$container" \
      API_CONTAINER='' KPB_RESTORE_CONFIRM=kpb_restore_drill \
      bash "$RESTORE_DB_SCRIPT" "$DUMP_FILE" </dev/null >/dev/null
    echo "restore_db_pass_${pass}=ok"
  done
else
  echo "warning: $RESTORE_DB_SCRIPT not found, restoring directly into the empty database" >&2
  case "$DUMP_FILE" in
    *.sql.gz)
      gunzip -c "$DUMP_FILE" | docker exec -i "$container" \
        psql -v ON_ERROR_STOP=1 -U postgres -d kpb_restore_drill >/dev/null
      ;;
    *.dump)
      docker cp "$DUMP_FILE" "$container:/tmp/restore.dump"
      docker exec "$container" pg_restore --exit-on-error --no-owner --no-privileges \
        -U postgres -d kpb_restore_drill /tmp/restore.dump >/dev/null
      ;;
    *) echo "error: unsupported dump format: $DUMP_FILE" >&2; exit 1 ;;
  esac
fi

table_count="$(docker exec "$container" psql -At -U postgres -d kpb_restore_drill \
  -c "SELECT count(*) FROM pg_catalog.pg_tables WHERE schemaname = 'public';")"
case "$table_count" in
  ''|*[!0-9]*) echo "error: restore produced an invalid table count" >&2; exit 1 ;;
esac
[ "$table_count" -gt 0 ] || { echo "error: restored database has no public tables" >&2; exit 1; }

echo "restored_public_tables=$table_count"
echo "RESTORE DRILL OK: the archive restored into disposable container $container."
echo "Cleanup removes the disposable container and volume automatically."
