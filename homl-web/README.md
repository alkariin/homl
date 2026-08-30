# homl-web

Go REST API for HOML. Run `make help` to see all available commands.

## Setup

Copy the templates and fill in secrets:

```bash
cp .env.example .env
```

If you need local configs:

```bash
cp .env.local.example .env.local          # proxy + CA cert settings
cp Makefile.local.example Makefile.local  # points to Dockerfile.local
```

Then generate the vendor directory (the shell can reach the proxy even if Docker cannot):

```bash
make vendor   # requires HTTP_PROXY / HTTPS_PROXY set in your shell or .env.local
```

On a real deployment, schedule `scripts/backup.sh` daily (root's crontab) and
rehearse a restore with `scripts/restore.sh` before going live —
[deployment.md §7](docs/deployment.md#7-backups).

## Start the full stack

```bash
make dev
```

Builds the image, starts MySQL, Redis and the backend, applies migrations, seeds
demo data, then attaches to the logs — `Ctrl-C` stops the stack. MySQL and Redis
data are persisted in named Docker volumes across restarts.

```
→ http://localhost:8080  (demo@homl.local / Demo1234!)
```

Once the database is migrated and seeded, plain

```bash
make up
```

is enough to start the stack again with live logs (no migrate/seed step).

## Backend development workflow

After modifying Go code, rebuild the backend image and restart the stack — the
MySQL and Redis volumes survive, so the data stays:

```bash
make up      # docker compose up --build
```

For rapid iteration without a Docker rebuild, run the Go process directly
against the containerized MySQL/Redis:

```bash
make local   # cd src && go run . (with the git describe version baked in)
```

## Local backend mode (Go process + Docker deps)

Start only MySQL and Redis:

```bash
make db-up
make migrateup
make seed          # optional demo data (idempotent: never duplicates the
                   # demo user's default categories, even after an E2EE purge
                   # deleted and recreated them)
```

Run the backend as a local Go process:

```bash
make local
```

## Database migrations

Schema changes live in `db/migrations` (golang-migrate format, one `.up.sql` /
`.down.sql` pair per step) and are applied against the running MySQL:

```bash
make migratecreate   # new migration pair
make migrateup       # apply everything pending
make migratedown     # roll back the last step
make migratefix      # force the version after a failed migration
```

The demo dataset is regenerated from Go (`make seed-gen` writes `db/seeder.sql`
with the data encrypted under the current `ENCRYPT_SECRET`), so a changed
secret means a re-seed.

## Testing

```bash
make test          # unit + HTTP integration tests (needs a local Go toolchain)
make test-docker   # same, in a golang container (no local Go needed)
make test-db       # DB-backed persistence tests (make db-up + migrateup first)
make test-e2e      # end-to-end tests against a running stack (make dev first)
```

See [TESTING.md](TESTING.md) for what each layer covers.

## Cleanup

```bash
make down    # stop the compose stack
make clean   # stop it and drop the named volumes, orphans and locally built images
```

## Documentation

The backend design docs live in [`docs/`](docs):
[architecture](docs/architecture.md) ·
[domain model](docs/domain-model.md) ·
[API reference](docs/api.md) ·
[auth flows](docs/auth-flows.md) ·
[end-to-end encryption](docs/e2ee.md) ·
[deployment](docs/deployment.md) ·
[default categories](docs/default-categories.md) ·
[tag synonyms](docs/tag-synonyms.md).

## Updating dependencies

```bash
# On a machine with internet access (set HTTP_PROXY/HTTPS_PROXY if needed):
make vendor        # runs go mod tidy && go mod vendor
```

