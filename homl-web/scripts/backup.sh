#!/usr/bin/env sh
# Dump the homl database from the MySQL container into a gzipped SQL file.
#
# The password never touches the host: the dump runs inside the container,
# which already holds MYSQL_ROOT_PASSWORD and MYSQL_DATABASE in its
# environment, and hands the password to mysqldump through MYSQL_PWD so it
# shows up neither in `ps` nor in the cron log. No .env is needed.
#
# Usage: scripts/backup.sh
#   BACKUP_DIR        where dumps land            (default /var/backups/homl)
#   BACKUP_KEEP_DAYS  delete dumps older than this (default 28, 0 keeps all)
#   MYSQL_CONTAINER   container name               (default mysql_container)
set -eu

BACKUP_DIR="${BACKUP_DIR:-/var/backups/homl}"
BACKUP_KEEP_DAYS="${BACKUP_KEEP_DAYS:-28}"
MYSQL_CONTAINER="${MYSQL_CONTAINER:-mysql_container}"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

stamp="$(date +%F_%H%M%S)"
target="$BACKUP_DIR/homl-$stamp.sql.gz"
tmp="$target.part"
trap 'rm -f "$tmp"' EXIT

# Single quotes on purpose: the variables expand inside the container.
# --single-transaction dumps one consistent snapshot without locking the
# service; --routines and --triggers keep the schema complete.
docker exec "$MYSQL_CONTAINER" sh -c '
  MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -u root \
    --single-transaction --routines --triggers --no-tablespaces \
    "$MYSQL_DATABASE"' | gzip -9 > "$tmp"

# mysqldump ends every successful dump with this line; anything else means
# the pipe broke half way and the file must not be kept.
if ! gzip -dc "$tmp" | tail -n 1 | grep -q '^-- Dump completed'; then
  echo "backup.sh: dump is incomplete, discarding $tmp" >&2
  exit 1
fi

mv "$tmp" "$target"
trap - EXIT
chmod 600 "$target"

if [ "$BACKUP_KEEP_DAYS" -gt 0 ]; then
  find "$BACKUP_DIR" -name 'homl-*.sql.gz' -type f -mtime +"$BACKUP_KEEP_DAYS" -delete
fi

echo "$target"
