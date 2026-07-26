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

## Start the full stack

```bash
make dev
```

Starts MySQL, Redis, and the backend in detached mode, then applies migrations and
seeds demo data. MySQL data is persisted in a named Docker volume across restarts.

```
→ http://localhost:8080  (demo@homl.local / Demo1234!)
```

To follow logs in the foreground instead:

```bash
make up
```

Stop everything:

```bash
make down
```

## Backend development workflow

After modifying Go code, rebuild and restart only the backend — MySQL and Redis keep running:

```bash
make reload
```

For rapid iteration without a Docker rebuild, run the Go process directly (requires the stack already running):

```bash
make local   # go run ./src
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

## Testing

```bash
make test          # unit + HTTP integration tests (needs a local Go toolchain)
make test-docker   # same, in a golang container (no local Go needed)
make test-e2e      # end-to-end tests against a running stack (make dev first)
```

## Updating dependencies

```bash
# On a machine with internet access (set HTTP_PROXY/HTTPS_PROXY if needed):
make vendor        # runs go mod tidy && go mod vendor
```

