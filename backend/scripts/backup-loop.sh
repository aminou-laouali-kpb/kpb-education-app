#!/bin/sh
# Continuous PostgreSQL backup loop, run by the `db-backup` service in
# docker-compose.yml (image: postgres:15-alpine, so pg_dump + gzip are present).
#
# Produces one gzipped dump per interval into $BACKUP_DIR (a host bind mount so
# the dumps survive `docker-compose down -v`, which would otherwise wipe named
# volumes), and prunes dumps older than $BACKUP_KEEP_DAYS.
#
# Connection uses the standard libpq env vars (PGHOST/PGUSER/PGPASSWORD/PGDATABASE)
# injected by docker-compose.
#
# Archive aussi, à chaque passage, le volume des pièces de dossier des élèves
# (`kpb-uploads`, monté en lecture seule sur $UPLOADS_DIR) en
# kpb-uploads-<horodatage>.tar.gz à côté des dumps, avec la même rétention :
# restaurer la base sans ces fichiers rendrait des dossiers pointant vers des
# documents perdus.
#
# NOTE: this protects against volume corruption, accidental drops and `down -v`,
# but NOT against loss of the whole VPS. Copy $BACKUP_DIR off-site as well
# (see docs/DEPLOYMENT.md, section "Sauvegardes").
set -eu
# Sans pipefail, `pg_dump | gzip` prend le statut de gzip : un pg_dump coupé
# en cours (OOM, redémarrage de la base) produisait un .sql.gz valide mais
# tronqué, accepté comme « backup ok ». L'ash de busybox (image alpine)
# supporte pipefail ; le marqueur de fin vérifié plus bas couvre de toute façon
# un shell qui ne le supporterait pas.
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi

: "${PGDATABASE:=kpb}"
: "${BACKUP_DIR:=/backups}"
: "${BACKUP_KEEP_DAYS:=14}"
: "${BACKUP_INTERVAL_SECONDS:=86400}" # daily
: "${UPLOADS_DIR:=/uploads}"

mkdir -p "$BACKUP_DIR"

log() { echo "[db-backup] $(date -u +%FT%TZ) $*"; }

while true; do
  ts=$(date -u +%Y%m%d-%H%M%SZ)
  out="$BACKUP_DIR/kpb-${PGDATABASE}-${ts}.sql.gz"
  log "dumping database '$PGDATABASE' -> $out"
  # Un dump au format texte se termine par ce marqueur : son absence signale
  # un flux tronqué, même si le gzip est structurellement valide.
  if pg_dump --no-owner --no-privileges "$PGDATABASE" | gzip -9 > "$out.tmp" \
    && gzip -dc "$out.tmp" | tail -n 5 | grep 'PostgreSQL database dump complete' >/dev/null; then
    mv "$out.tmp" "$out"
    log "backup ok ($(du -h "$out" | cut -f1))"

    # Retention: remove dumps older than BACKUP_KEEP_DAYS — only after a dump
    # has just been verified, so a run of failures never prunes the last good
    # backups away.
    find "$BACKUP_DIR" -name 'kpb-*.sql.gz' -type f -mtime +"$BACKUP_KEEP_DAYS" -delete 2>/dev/null || true
  else
    log "ERROR: pg_dump failed or dump is incomplete, keeping previous backups"
    rm -f "$out.tmp"
  fi

  # Pièces de dossier (volume kpb-uploads). Indépendant du dump : un échec ici
  # n'empêche pas la sauvegarde de la base, et inversement.
  if [ -d "$UPLOADS_DIR" ]; then
    up="$BACKUP_DIR/kpb-uploads-${ts}.tar.gz"
    log "archiving uploads '$UPLOADS_DIR' -> $up"
    # `tar -t` relit toute l'archive : un flux coupé ou corrompu est refusé.
    if tar -czf "$up.tmp" -C "$UPLOADS_DIR" . && tar -tzf "$up.tmp" >/dev/null; then
      mv "$up.tmp" "$up"
      log "uploads archive ok ($(du -h "$up" | cut -f1))"
      # Même rétention que les dumps, et seulement après une archive vérifiée.
      find "$BACKUP_DIR" -name 'kpb-uploads-*.tar.gz' -type f -mtime +"$BACKUP_KEEP_DAYS" -delete 2>/dev/null || true
    else
      log "ERROR: uploads archive failed, keeping previous archives"
      rm -f "$up.tmp"
    fi
  else
    log "WARNING: uploads directory '$UPLOADS_DIR' not mounted, uploads not archived"
  fi

  sleep "$BACKUP_INTERVAL_SECONDS"
done
