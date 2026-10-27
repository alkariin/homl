#!/bin/sh
# Installed as /app/migrate in the API image: applies the schema migrations
# baked into that image (the ones of its own version) to the database the API
# is configured for, from the same MYSQL_* environment. With the published
# image (docs/deployment.md §3), from the compose folder:
#
#   docker compose run --rm homlback /app/migrate            # up
#   docker compose run --rm homlback /app/migrate version
#   docker compose run --rm homlback /app/migrate down 1
set -eu
[ $# -eq 0 ] && set -- up

exec migrate -path /app/migrations \
  -database "mysql://$MYSQL_USER:$MYSQL_PASSWORD@tcp($MYSQL_ADDRESS)/$MYSQL_DATABASE" \
  "$@"
