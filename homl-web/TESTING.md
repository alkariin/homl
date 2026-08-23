# Testing the HOML backend

## The testing pyramid

| Layer | Location | What it covers | Dependencies |
|---|---|---|---|
| **Unit** | `src/internal/application/*_test.go`, `src/internal/apperror/*_test.go`, `src/internal/domain/e2ee/*_test.go`, `src/internal/infrastructure/{auth,config,crypto,mail}/*_test.go` | Business logic with mocked repositories; JWT, field encryption, config validation, the mailers and the error helpers | none |
| **HTTP / integration** | `src/internal/infrastructure/web/router_test.go` | The real Gin router (routing, JWT middleware, JSON binding, validation, status codes & response bodies) with mocked services | none |
| **DB-backed** | `src/test/dbtest/*_test.go` (build tag `dbtest`) | The real SQL of the persistence layer: cross-tenant isolation, tag/synonym lifecycle, the atomic E2EE migration and purge | `make db-up` + `make migrateup` |
| **End-to-end** | `src/test/e2e/e2e_test.go` (build tag `e2e`) | Full flow over real HTTP against a running stack (API + MySQL + Redis) | `make dev` |

The first two layers are in-process and deterministic — no database, no network —
so they run on every commit; each HTTP test fires a real request and asserts the
**status code** and **JSON body**. The last two are gated behind build tags
(`dbtest`, `e2e`) so `go test ./...` never picks them up.

## Running the tests

```bash
cd homl-web

make test          # unit + HTTP integration tests (needs a local Go toolchain)
make test-cover    # same, with a coverage summary
make test-docker   # same, but inside a golang container (no local Go needed)
make test-db       # DB-backed persistence tests against a migrated MySQL
make test-e2e      # end-to-end tests against a running stack
```

Under the hood these are plain `go test` invocations:

```bash
cd homl-web/src
go test ./...                            # unit + HTTP integration
go test -tags dbtest ./test/dbtest/...   # DB-backed (MySQL must be up + migrated)
go test -tags e2e ./test/e2e/...         # end-to-end (stack must be up)
```

### DB-backed prerequisites

These tests drive the repositories directly against a real MySQL, because the
gaps they hunt — a query missing its `idUser` scope, a cascade that deletes too
much, a migration that half-commits — live in the SQL itself, which mocked
repositories cannot exercise. A migrated database is enough (no API, no Redis):

```bash
cd homl-web
make db-up         # MySQL + Redis containers
make migrateup
make test-db
```

The target database is configurable through `DBTEST_DSN` (default matches
`make db-up`). The tests create and delete their own users, so they are safe to
run against a dev database, but never against one holding real data.

### End-to-end prerequisites

E2E tests talk to a live stack and are gated behind the `e2e` build tag so they
never run during `go test ./...`. Boot the stack first:

```bash
cd homl-web
make dev           # builds, starts the stack, migrates, seeds the demo user
make test-e2e
```

They are configurable via environment variables (defaults match `make dev`):

| Variable | Default |
|---|---|
| `E2E_BASE_URL` | `http://localhost:8080/api` |
| `E2E_USERNAME` | `demo@homl.local` |
| `E2E_PASSWORD` | `Demo1234!` |

## How the layers are wired

- **Repository mocks** (`src/test/mocks/*_repo.go`) are programmable `testify`
  mocks of the `domain/<aggregate>.Repository` interfaces. The service unit
  tests inject them to drive business logic in isolation.
- **Service mocks** (`src/test/mocks/services.go`) are `testify` mocks of the
  `application.*Service` interfaces. The HTTP tests inject them into the real
  `web` handlers so the router runs end-to-end minus the services' internals.
- **Repository fixtures** (`src/test/dbtest`) use the real
  `infrastructure/persistence` implementations over a live MySQL — no mocks, so
  the SQL, the constraints and the transactions are what is under test.
- Crypto secrets needed by the code are set up per package in `setup_test.go` /
  `TestMain`. The reference data (`constants.json`) is embedded in the binary
  via `internal/domain/masterdata`, so tests no longer need a copy of the file.

## Frontend tests

The Flutter side has its own suites — `flutter test` (unit + widget, mocked
HTTP and pure-Dart crypto) and an opt-in integration test driving the full E2EE
lifecycle on a device against a live backend. See
[../homl-ui/README.md](../homl-ui/README.md).
