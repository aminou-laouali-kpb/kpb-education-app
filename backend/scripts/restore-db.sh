#!/usr/bin/env bash
# Restore a PostgreSQL dump into the running `db` container, REPLACING the
# target database. Run from the VPS host (next to docker-compose.yml).
#
#   Usage: POSTGRES_USER=... POSTGRES_DB=... ./backend/scripts/restore-db.sh ./backups/kpb-kpb_prod-YYYYMMDD-HHMMSSZ.sql.gz
#
# Accepte les deux formats produits par la chaîne de sauvegarde :
#   - kpb-*.sql.gz      : dump texte de backup-loop.sh (service db-backup) ;
#   - predeploy-*.dump  : dump au format custom de l'étape pré-déploiement.
#
# Ces dumps n'ont pas de `--clean` : les rejouer dans la base EXISTANTE
# échouait au premier CREATE (« already exists »). Le script restaure donc
# dans une base NEUVE (<base>_restore_<horodatage>), vérifie le résultat, puis
# échange les noms : la base actuelle est conservée intacte sous
# <base>_pre_restore_<horodatage> (retour arrière possible, à supprimer à la
# main une fois la restauration validée). Un échec avant l'échange laisse la
# base actuelle telle quelle.
#
# Garde-fous : l'API doit être arrêtée (docker compose stop api), et il faut
# confirmer en tapant le nom de la base, ou poser KPB_RESTORE_CONFIRM=<base>
# pour un lancement non interactif.
set -euo pipefail

FILE="${1:?usage: restore-db.sh <backup.sql.gz|backup.dump>}"
: "${POSTGRES_USER:?set POSTGRES_USER (same as your .env)}"
: "${POSTGRES_DB:=kpb}"
DB_CONTAINER="${DB_CONTAINER:-kpb_db}"
# Vide = pas de vérification (exercice de restauration sur un conteneur jetable).
API_CONTAINER="${API_CONTAINER-kpb_api}"
MAINTENANCE_DB="${MAINTENANCE_DB:-postgres}"

if [ ! -f "$FILE" ]; then
  echo "backup file not found: $FILE" >&2
  exit 1
fi

# Le nom de base est interpolé dans du SQL : on n'accepte qu'un identifiant simple.
case "$POSTGRES_DB" in
  ''|*[!A-Za-z0-9_]*) echo "error: unsupported database name: '$POSTGRES_DB'" >&2; exit 2 ;;
esac

# Un dump tronqué se rejoue « sans erreur » mais partiellement : on le refuse
# avant de toucher à quoi que ce soit.
case "$FILE" in
  *.sql.gz)
    gzip -t "$FILE"
    gzip -dc "$FILE" | tail -n 5 | grep 'PostgreSQL database dump complete' >/dev/null || {
      echo "error: plain dump is truncated (no completion marker): $FILE" >&2
      exit 1
    }
    ;;
  *.dump)
    [ "$(LC_ALL=C head -c 5 "$FILE")" = "PGDMP" ] || {
      echo "error: custom dump has invalid header: $FILE" >&2
      exit 1
    }
    ;;
  *) echo "error: unsupported dump format (expected .sql.gz or .dump): $FILE" >&2; exit 1 ;;
esac

if [ -n "$API_CONTAINER" ] \
  && [ "$(docker inspect -f '{{.State.Running}}' "$API_CONTAINER" 2>/dev/null || true)" = "true" ]; then
  echo "error: container $API_CONTAINER is running — stop it first: docker compose stop api" >&2
  exit 1
fi

ts="$(date -u +%Y%m%d%H%M%S)"
TMP_DB="${POSTGRES_DB}_restore_${ts}"
OLD_DB="${POSTGRES_DB}_pre_restore_${ts}"
[ "${#OLD_DB}" -le 63 ] || { echo "error: database name too long for the swap: $POSTGRES_DB" >&2; exit 2; }

psql_admin() {
  docker exec "$DB_CONTAINER" psql -X -q -At -v ON_ERROR_STOP=1 \
    -U "$POSTGRES_USER" -d "$MAINTENANCE_DB" "$@"
}

target_exists="$(psql_admin -c "SELECT 1 FROM pg_database WHERE datname = '$POSTGRES_DB'")"

echo "Restoring $FILE into database '$POSTGRES_DB' (container $DB_CONTAINER)."
if [ "$target_exists" = "1" ]; then
  echo "The current '$POSTGRES_DB' will be REPLACED (kept as '$OLD_DB' for rollback)."
fi
if [ "${KPB_RESTORE_CONFIRM:-}" != "$POSTGRES_DB" ]; then
  if [ -t 0 ]; then
    read -r -p "Tapez le nom de la base ($POSTGRES_DB) pour confirmer : " answer
    [ "$answer" = "$POSTGRES_DB" ] || { echo "Abandon : confirmation incorrecte." >&2; exit 1; }
  else
    echo "error: non-interactive run — set KPB_RESTORE_CONFIRM=$POSTGRES_DB to confirm" >&2
    exit 1
  fi
fi

# Étape de l'échange, lue par le trap : chaque état sait remettre la base
# cible sous son nom si le script s'arrête (erreur, ou signal hors de la
# fenêtre d'échange).
#   restoring      : la base actuelle est intacte, seule la base neuve existe en plus
#   locked         : connexions interdites sur la base actuelle, pas encore renommée
#   target_renamed : base actuelle renommée en OLD, la restaurée pas encore en place
#   swapped        : la restaurée porte le nom cible (fin de l'échange)
state=restoring
manual_fix() {
  echo "MANUAL ACTION REQUIRED — $1" >&2
  echo "  docker exec -i $DB_CONTAINER psql -U $POSTGRES_USER -d $MAINTENANCE_DB -c '$2'" >&2
}
cleanup() {
  case "$state" in
    restoring) ;;
    locked)
      psql_admin -c "ALTER DATABASE \"$POSTGRES_DB\" WITH ALLOW_CONNECTIONS true" >/dev/null 2>&1 \
        || manual_fix "'$POSTGRES_DB' still refuses connections" \
          "ALTER DATABASE \"$POSTGRES_DB\" WITH ALLOW_CONNECTIONS true"
      ;;
    target_renamed)
      # Retour arrière : la base d'origine reprend son nom.
      if psql_admin -c "ALTER DATABASE \"$OLD_DB\" RENAME TO \"$POSTGRES_DB\"" >/dev/null 2>&1; then
        echo "rollback: previous database put back as '$POSTGRES_DB'" >&2
        psql_admin -c "ALTER DATABASE \"$POSTGRES_DB\" WITH ALLOW_CONNECTIONS true" >/dev/null 2>&1 \
          || manual_fix "'$POSTGRES_DB' still refuses connections" \
            "ALTER DATABASE \"$POSTGRES_DB\" WITH ALLOW_CONNECTIONS true"
      else
        # Sans retour arrière possible, on garde AUSSI la restaurée : aucune
        # base n'est supprimée tant qu'aucune ne porte le nom cible.
        manual_fix "no database is named '$POSTGRES_DB'; previous one is '$OLD_DB', restored one is '$TMP_DB'" \
          "ALTER DATABASE \"$OLD_DB\" RENAME TO \"$POSTGRES_DB\""
        return
      fi
      ;;
    swapped) return ;;
  esac
  psql_admin -c "DROP DATABASE IF EXISTS \"$TMP_DB\" WITH (FORCE)" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# 1) Restauration dans une base neuve : aucun objet préexistant, donc ni
#    « already exists » ni COPY ajoutés à des lignes existantes.
psql_admin -c "CREATE DATABASE \"$TMP_DB\""
case "$FILE" in
  *.sql.gz)
    gzip -dc "$FILE" | docker exec -i "$DB_CONTAINER" \
      psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$TMP_DB" >/dev/null || {
      echo "error: restore failed, current database left untouched" >&2
      exit 1
    }
    ;;
  *.dump)
    # Fichier copié dans le conteneur : pg_restore lisant un flux non
    # « seekable » peut refuser une archive custom selon l'ordre de sa TOC.
    docker cp "$FILE" "$DB_CONTAINER:/tmp/kpb-restore-${ts}.dump"
    restore_status=0
    docker exec "$DB_CONTAINER" pg_restore --exit-on-error --no-owner --no-privileges \
      -U "$POSTGRES_USER" -d "$TMP_DB" "/tmp/kpb-restore-${ts}.dump" || restore_status=$?
    docker exec "$DB_CONTAINER" rm -f "/tmp/kpb-restore-${ts}.dump" || true
    [ "$restore_status" -eq 0 ] || { echo "error: pg_restore failed, current database left untouched" >&2; exit 1; }
    ;;
esac

table_count="$(docker exec -i "$DB_CONTAINER" psql -X -At -U "$POSTGRES_USER" -d "$TMP_DB" \
  -c "SELECT count(*) FROM pg_catalog.pg_tables WHERE schemaname = 'public'")"
case "$table_count" in
  ''|*[!0-9]*|0) echo "error: restored database has no public tables, current database left untouched" >&2; exit 1 ;;
esac
echo "restored_public_tables=$table_count"

# 2) Échange des noms. Plus aucune connexion n'est admise sur la base actuelle
#    (db-backup s'y reconnecte chaque jour), puis les sessions restantes sont
#    coupées : RENAME exige une base sans connexion. Ctrl-C et TERM sont
#    ignorés pendant l'échange : une interruption entre les deux RENAME
#    laissait aucune base sous le nom cible. Toute erreur ici est rattrapée par
#    le trap EXIT selon `state`.
trap '' INT TERM
if [ "$target_exists" = "1" ]; then
  state=locked
  psql_admin -c "ALTER DATABASE \"$POSTGRES_DB\" WITH ALLOW_CONNECTIONS false"
  psql_admin -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$POSTGRES_DB' AND pid <> pg_backend_pid()" >/dev/null
  psql_admin -c "ALTER DATABASE \"$POSTGRES_DB\" RENAME TO \"$OLD_DB\""
  state=target_renamed
fi
psql_admin -c "ALTER DATABASE \"$TMP_DB\" RENAME TO \"$POSTGRES_DB\""
state=swapped
trap - INT TERM

if [ "$target_exists" = "1" ]; then
  # Non bloquant : la restauration est en place ; seule la base de retour
  # arrière reste fermée aux connexions.
  psql_admin -c "ALTER DATABASE \"$OLD_DB\" WITH ALLOW_CONNECTIONS true" >/dev/null \
    || manual_fix "rollback copy '$OLD_DB' still refuses connections" \
      "ALTER DATABASE \"$OLD_DB\" WITH ALLOW_CONNECTIONS true"
fi

echo "Restore complete: '$POSTGRES_DB' now holds $FILE."
if [ "$target_exists" = "1" ]; then
  echo "Previous database kept as '$OLD_DB'. Once the restore is validated, drop it:"
  echo "  docker exec -i $DB_CONTAINER psql -U $POSTGRES_USER -d $MAINTENANCE_DB -c 'DROP DATABASE \"$OLD_DB\"'"
fi
echo "Restart the API: docker compose up -d api"
