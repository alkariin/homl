# Deployment

Running HOML on a server you own: a single Linux host with Docker, the API
behind a reverse proxy that terminates TLS, MySQL and Redis on the loopback.
This is the self-hosting path — the app is distributed as source, not through
an app store.

Companion documents: [architecture.md](architecture.md) (what the service is
made of), [auth-flows.md](auth-flows.md) (the email path), and
[../README.md](../README.md) for the development workflow, which this document
deliberately does **not** reuse: `make dev` is a developer convenience and
seeds a demo account.

## 1. What you need

- A host with Docker Engine and the Compose v2 plugin.
- A domain name pointing at it, if you want HTTPS (you do — see §4).
- Outbound SMTP credentials, if you want password reset to work (§6).

Nothing else: the API, MySQL and Redis all come from the compose file.

## 2. Secrets

Copy the template and fill **every** secret with a fresh random value:

```bash
cp .env.example .env
openssl rand -base64 32   # once per secret
```

| Variable | Consequence of losing or changing it |
|---|---|
| `ACCESS_SECRET` | Every access token is rejected — users re-login. Harmless. |
| `REFRESH_SECRET` | Every session dies — users re-login. Harmless. |
| `ENCRYPT_SECRET` | **Irreversible data loss.** Category names, tag names and event descriptions are encrypted at rest with keys derived from it. Change it and the existing rows can never be decrypted again. |

`ENCRYPT_SECRET` is therefore part of your backup (§7), stored somewhere other
than the server it protects. Note that it does *not* protect the data of
end-to-end encrypted users, whose content is already opaque to the server —
see [e2ee.md](e2ee.md).

The service refuses to start on a secret that is empty, shorter than 32
characters, or still contains `change_me`.

Set the production values too:

```ini
ENVIRONMENT=PROD                      # shorter token lifetime, gin in release mode
CORS_ORIGIN=https://homl.example.com  # the origin serving the web client, no wildcard
TRUSTED_PROXIES=172.16.0.0/12         # see §4 — required behind a proxy
```

`.env` is git-ignored and must stay that way; it is the one file on the host
that is worth stealing.

## 3. First deploy

```bash
git clone https://github.com/alkariin/homl.git
cd homl/homl-web
cp .env.example .env                       # then edit it, see §2
cp docker-compose.prod.example.yml docker-compose.prod.yml

docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

The overlay adds `restart: unless-stopped` and binds the API to `127.0.0.1`,
so only the reverse proxy can reach it. MySQL and Redis are already bound to
the loopback in the base file.

Apply the schema — the API starts fine without it, but every request fails
until the tables exist:

```bash
migrate -path db/migrations \
  -database "mysql://homl:<MYSQL_PASSWORD>@tcp(127.0.0.1:3306)/homl" up
```

(`make migrateup` does the same, reading `.env`. Install golang-migrate from
its [releases](https://github.com/golang-migrate/migrate/releases) if the
binary is missing.)

> **Never run `make seed` on a server.** It creates `demo@homl.local` with a
> password published in this repository.

Check the service:

```bash
curl -fsS http://127.0.0.1:8080/healthz
```

## 4. TLS and the reverse proxy

The API speaks plain HTTP and does not terminate TLS. Put a proxy in front of
it — with the app sending a password on every login and a bearer token on
every request, HTTPS is not optional the moment the service leaves your
machine.

Caddy is the shortest path, since it obtains and renews the certificate on its
own:

```caddyfile
homl.example.com {
    reverse_proxy 127.0.0.1:8080
}
```

nginx equivalent (certificate from certbot):

```nginx
server {
    listen 443 ssl;
    server_name homl.example.com;

    ssl_certificate     /etc/letsencrypt/live/homl.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/homl.example.com/privkey.pem;

    # The 32 MiB E2EE migration payload must fit (docs/e2ee.md).
    client_max_body_size 32m;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### TRUSTED_PROXIES is mandatory here

Behind a proxy, every request reaches the API from the proxy's address. The
per-IP rate limits that protect login, refresh and password reset would then
share **one** budget for all your users: ten failed logins anywhere and
everyone is locked out for a minute.

`TRUSTED_PROXIES` fixes that by telling the API which peers may set
`X-Forwarded-For`:

- proxy running on the host, API in Docker → the proxy reaches the container
  through the Docker bridge, so trust that range: `TRUSTED_PROXIES=172.16.0.0/12`;
- proxy in a container on the same compose network → same range;
- no proxy at all → leave it **empty**, which trusts nobody and reads the real
  peer address.

Getting it wrong in the other direction is worse: trusting a peer that is not
your proxy lets a client forge its own address and walk past the rate limits
entirely. Never put `0.0.0.0/0` there.

Verify after deploying — a wrong value shows up as every log line carrying the
same client IP:

```bash
docker compose logs homlback | tail -20
```

## 5. Building the clients

The Flutter app is built against one API URL, baked in at compile time:

```bash
cd homl-ui
flutter build web --release \
  --dart-define=API_BASE_URL=https://homl.example.com/api \
  --no-tree-shake-icons
```

Serve `build/web` from the same origin you put in `CORS_ORIGIN`. The
`--no-tree-shake-icons` flag is not optional — see the note in
[../../homl-ui/README.md](../../homl-ui/README.md).

For Android, the same `--dart-define` applies to `flutter build apk`. A release
APK is currently signed with the debug key, so it cannot be upgraded by a
properly signed build later: set up a keystore before distributing one.

## 6. Password-reset email

With `SMTP_HOST` empty, the 6-digit reset code is written to the application
log instead of being sent, and users cannot recover their account on their
own. That is fine while you are the only user, and not fine afterwards.

Use a transactional mail provider (Brevo, Mailgun, SES, Postmark…) rather than
running your own mail server: a self-hosted MTA on a fresh IP lands in spam.
Create an API/SMTP credential there and fill in:

```ini
SMTP_HOST=smtp-relay.example.net
SMTP_PORT=587            # STARTTLS; 465 for implicit TLS
SMTP_FROM=no-reply@homl.example.com
SMTP_USER=<provider username, often not the From address>
SMTP_PASSWORD=<provider secret>
```

Then publish SPF, DKIM and DMARC records for the `SMTP_FROM` domain, following
your provider's instructions — without them the mail is rejected or filed as
spam regardless of the code. The exact behaviour of the mailer (async send,
timeouts, encoding) is documented in [auth-flows.md](auth-flows.md).

## 7. Backups

The data lives in the `mysql-data` Docker volume. A volume is not a backup: it
disappears with `docker compose down --volumes` and with the host.

[`scripts/backup.sh`](../scripts/backup.sh) dumps the database into a gzipped
SQL file — `mysqldump` writes the whole schema and its rows as a script that
recreates it anywhere:

```bash
sudo /srv/homl/homl-web/scripts/backup.sh
# → /var/backups/homl/homl-2026-08-23_031500.sql.gz
```

What it does, and why:

- The dump runs **inside** the container, which already knows
  `MYSQL_ROOT_PASSWORD` and `MYSQL_DATABASE`, and passes the password to
  `mysqldump` through `MYSQL_PWD`. It never appears in `ps`, in the cron log
  or on the host at all, and the script needs no `.env`.
- `--single-transaction` takes one consistent snapshot; the service keeps
  running while it is written.
- The file is written to `.part` first and only renamed once the last line
  reads `-- Dump completed`, so a broken pipe never leaves a truncated dump
  that looks valid. The directory is `700`, each dump `600`.
- Dumps older than `BACKUP_KEEP_DAYS` (default 28) are deleted. `BACKUP_DIR`
  (default `/var/backups/homl`) and `MYSQL_CONTAINER` (default
  `mysql_container`) can be overridden the same way.

Run it daily from root's crontab — root because `/var/backups` and the Docker
socket both need it:

```cron
15 3 * * * /srv/homl/homl-web/scripts/backup.sh >> /var/log/homl-backup.log 2>&1
```

Copy those dumps off the host, together with `.env` — a dump without its
`ENCRYPT_SECRET` restores rows nobody can read (§2).

### Restoring

[`scripts/restore.sh`](../scripts/restore.sh) loads a dump back. Rehearse it
into a throwaway database first — an untested backup is a guess:

```bash
sudo /srv/homl/homl-web/scripts/restore.sh \
  /var/backups/homl/homl-2026-08-23_031500.sql.gz homl_restore
# check a few rows, then:
docker exec mysql_container sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -u root -e "DROP DATABASE homl_restore"'
```

Without a database name the dump replaces the **live** database; the script
asks you to type its name before it does (`RESTORE_YES=1` skips the prompt
for scripted use). It refuses any file that does not end with
`-- Dump completed`.

Redis holds only sessions, reset codes and rate-limit counters: losing it logs
everyone out and costs nothing else. It needs no backup.

## 8. Upgrades

```bash
cd /srv/homl && git pull
cd homl-web
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
make migrateup     # or the migrate command from §3
```

Take a dump first (§7) whenever the release adds a migration. Migrations run
forward only in practice: `make migratedown` exists but rolling back a schema
under live data is a manual, case-by-case operation.

To roll the code back without touching the schema, check out the previous tag
and rebuild — the migrations of a newer version are additive, so an older
binary keeps working against a newer schema in most cases, but verify rather
than assume.

## 9. Operating it

- **Health**: `GET /healthz`, unauthenticated and unthrottled, is what the
  container healthcheck and any uptime monitor should poll.
- **Logs**: `docker compose logs -f homlback`. Errors are logged with their
  cause; the HTTP response only ever carries a generic `INTERNAL`, so the log
  is the only place the real error appears.
- **Restart**: the overlay's `restart: unless-stopped` covers crashes and host
  reboots. Shutdown is graceful (in-flight requests get 5 s).

## 10. Pre-flight checklist

- [ ] `.env` filled with fresh secrets, backed up off-host
- [ ] `ENVIRONMENT=PROD`, `CORS_ORIGIN` set to the real origin
- [ ] `TRUSTED_PROXIES` matching the actual proxy (§4)
- [ ] Migrations applied, **seeder never run**
- [ ] TLS working, port 8080 not reachable from outside
- [ ] `3306` and `6379` not reachable from outside (`ss -ltn` on the host)
- [ ] SMTP configured, a real reset email received
- [ ] `scripts/backup.sh` in root's crontab, dumps copied off-host, one restore rehearsed with `scripts/restore.sh`
- [ ] Client built with the production `API_BASE_URL`
