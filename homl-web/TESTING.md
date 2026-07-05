# Testing the HOML backend

## The testing pyramid

| Layer | Location | What it covers | Dependencies |
|---|---|---|---|
| **Unit** | `src/internal/application/*_test.go`, `src/internal/{apperror,crypto,token}/*_test.go` | Business logic with mocked repositories; crypto, JWT and error helpers | none |
| **HTTP / integration** | `src/internal/infrastructure/web/router_test.go` | The real Gin router (routing, JWT middleware, JSON binding, validation, status codes & response bodies) with mocked services | none |
| **End-to-end** | `src/test/e2e/e2e_test.go` (build tag `e2e`) | Full flow over real HTTP against a running stack (API + MySQL + Redis) | `make dev` |

Each test fires a real request and asserts the **status code** and **JSON body**, in-process and
deterministic, so it runs on every commit without a database.

## Running the tests

```bash
cd homl-web

make test          # unit + HTTP integration tests (needs a local Go toolchain)
make test-cover    # same, with a coverage summary
make test-docker   # same, but inside a golang container (no local Go needed)
make test-e2e      # end-to-end tests against a running stack
```

Under the hood these are plain `go test` invocations:

```bash
cd homl-web/src
go test ./...                         # unit + HTTP integration
go test -tags e2e ./test/e2e/...      # end-to-end (stack must be up)
```

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
- Crypto secrets needed by the code are set up per package in `setup_test.go` /
  `TestMain`. The reference data (`constants.json`) is embedded in the binary
  via `internal/domain/masterdata`, so tests no longer need a copy of the file.
