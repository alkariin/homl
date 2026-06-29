# Testing the HOML backend

## The testing pyramid

| Layer | Location | What it covers | Dependencies |
|---|---|---|---|
| **Unit** | `src/service/*_test.go`, `src/helper/*_test.go` | Business logic with mocked repositories; crypto, JWT and error helpers | none |
| **HTTP / integration** | `src/http_test.go` | The real Gin router (routing, JWT middleware, JSON binding, validation, status codes & response bodies) with mocked services | none |
| **End-to-end** | `src/e2e/e2e_test.go` (build tag `e2e`) | Full flow over real HTTP against a running stack (API + MySQL + Redis) | `make dev` |

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
go test ./...                    # unit + HTTP integration
go test -tags e2e ./e2e/...      # end-to-end (stack must be up)
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

- **Repository mocks** (`src/repository/mocks/`) are programmable `testify`
  mocks of the `model.*Repository` interfaces. The service unit tests inject
  them to drive business logic in isolation.
- **Service mocks** (`src/service/mocks/`) are `testify` mocks of the
  `model.*Service` interfaces. The HTTP tests inject them into a real
  `controller.Handler` so the router runs end-to-end minus the services'
  internals.
- Crypto secrets and `constants.json` needed by the code are set up per package
  in `setup_test.go` / `TestMain`.

