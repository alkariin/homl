#!/usr/bin/env sh
# Load a dump written by scripts/backup.sh into the MySQL container.
#
# Usage: scripts/restore.sh <dump.sql.gz> [database]
#
# Without a database name the dump goes back into the live database (the
# container's MYSQL_DATABASE), replacing every table it contains — the script
# asks for confirmation first. With a name, the dump is loaded into that
# database, created if missing, which is how a restore is rehearsed:
#
#   scripts/restore.sh /var/backups/homl/homl-2026-08-23_031500.sql.gz homl_restore
#
# Set RESTORE_YES=1 to skip the confirmation (scripted use).
#   MYSQL_CONTAINER  container name (default mysql_container)
set -eu

MYSQL_CONTAINER="${MYSQL_CONTAINER:-mysql_container}"

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "usage: $0 <dump.sql.gz> [database]" >&2
  exit 2
fi
dump="$1"
[ -r "$dump" ] || { echo "restore.sh: cannot read $dump" >&2; exit 1; }

if ! gzip -dc "$dump" | tail -n 1 | grep -q '^-- Dump completed'; then
  echo "restore.sh: $dump is not a complete mysqldump file" >&2
  exit 1
fi

live="$(docker exec "$MYSQL_CONTAINER" sh -c 'printf %s "$MYSQL_DATABASE"')"
db="${2:-$live}"

if [ "$db" = "$live" ] && [ "${RESTORE_YES:-}" != "1" ]; then
  printf 'This replaces the LIVE database "%s" with %s. Type the database name to continue: ' "$db" "$dump"
  read -r answer
  [ "$answer" = "$db" ] || { echo "restore.sh: aborted" >&2; exit 1; }
fi

# Same trick as backup.sh: the root password stays inside the container.
docker exec "$MYSQL_CONTAINER" sh -c '
  MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -u root \
    -e "CREATE DATABASE IF NOT EXISTS \`$1\`"' sh "$db"

gzip -dc "$dump" | docker exec -i "$MYSQL_CONTAINER" sh -c '
  MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -u root "$1"' sh "$db"

echo "restored $dump into $db"
