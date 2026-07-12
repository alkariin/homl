# Architecture

How the backend is layered and wired. Companion documents:
[domain-model.md](domain-model.md) (the *what*),
[auth-flows.md](auth-flows.md) and [api.md](api.md) (the HTTP surface).

## Layers

The backend follows a ports-and-adapters (hexagonal) layout under
`src/internal`: the domain defines the model and the persistence ports, the
application layer implements the use cases against those ports, and the
infrastructure provides every adapter — inbound (HTTP) and outbound
(MySQL/Redis, JWT, crypto, SMTP).

```mermaid
flowchart TB
    subgraph infra_in ["infrastructure (inbound)"]
        WEB["web<br/>Gin router, handlers,<br/>auth + rate-limit + timeout middleware"]
    end

    subgraph app ["application"]
        SVC["services (use cases)<br/>users, categories, tags,<br/>events, settings"]
    end

    subgraph dom ["domain"]
        MODEL["aggregates + Repository ports<br/>user, category, event,<br/>masterdata"]
    end

    subgraph infra_out ["infrastructure (outbound)"]
        PERS["persistence<br/>MySQL + Redis repositories"]
        AUTH["auth<br/>JWT mint/verify"]
        CRYPTO["crypto<br/>AES-GCM field encryption"]
        RL["ratelimit<br/>Redis fixed window"]
        DB[("MySQL / Redis<br/>clients (db)")]
    end

    CFG["config<br/>env → Config"]
    MAIN["main.go<br/>dependency injection"]

    WEB --> SVC
    SVC --> MODEL
    PERS -. implements Repository ports .-> MODEL
    AUTH -. implements TokenIssuer / TokenParser .-> SVC
    CRYPTO -. implements Encryptor .-> SVC
    RL -. implements RateLimiter .-> WEB
    PERS --> DB
    MAIN --> CFG
    MAIN --> WEB
```

Dependency rule: arrows only point inward. `domain` imports nothing outside
itself; `application` imports only `domain` (plus stdlib); every
infrastructure package depends on the ports it implements, never the other
way around. `config` is read once in `main` — no other package calls
`os.Getenv`.

## Ports and adapters

| Port (interface) | Defined in | Adapter |
| --- | --- | --- |
| `user.Repository`, `category.Repository`, `event.Repository` | `domain/*` | `infrastructure/persistence` (MySQL; the users repository also owns the Redis auth store) |
| `application.TokenIssuer` (mint/verify token pairs) | `application` | `infrastructure/auth.JWT` |
| `application.Encryptor` (at-rest field encryption) | `application` | `infrastructure/crypto.AES` |
| `application.*Service` (use-case ports) | `application` | consumed by `web` handlers |
| `web.TokenParser` (read tokens off requests) | `web` | `infrastructure/auth.JWT` |
| `web.SessionStore` (resolve session → user id) | `web` | users repository (Redis) |
| `web.Authenticator` | `web` | `web.TokenAuthenticator` (TokenParser + SessionStore) |
| `web.RateLimiter` | `web` | `infrastructure/ratelimit.RedisLimiter` |

All wiring happens in `main.go` (`inject`): adapters are built from the
config, repositories from the data sources, services from repositories, and
handlers from services — plain constructor injection, no framework.

## Request lifecycle

```
CORS middleware
  → handler timeout (HANDLER_TIMEOUT, 503 on overrun)
    → per-route middleware: rate limit (public auth) or TokenAuthMiddleware (protected)
      → handler: bind + validate input, read user id from context
        → application service: use-case logic, encryption of sensitive fields
          → repository: SQL scoped by user id / Redis
```

Two cross-cutting rules the layers enforce:

- **Tenancy** — handlers never trust ids from the body; the authenticated
  user id comes from the middleware context and every repository query is
  scoped by it.
- **Encryption at rest** — category names, tag names and event
  descriptions are encrypted before they cross a persistence port
  (`enc*` parameters). The scheme is deterministic authenticated encryption
  (AES-GCM with an HMAC-derived synthetic nonce): deterministic so encrypted
  values can be looked up by equality, authenticated so tampering fails on
  decrypt.

## Data stores

| Store | Holds |
| --- | --- |
| MySQL | `Users` (credentials, pin, pkey, challenge, settings columns), `Categories`, `Tags`, `Events`, `EventsTags` |
| Redis | Access/refresh sessions (`uuid → user_id`, TTL = token expiry), single-use password-reset tokens (15 min TTL), rate-limit counters |

Schema migrations live in `db/migrations` (golang-migrate format).

## Configuration

Loaded from the environment (with `.env` fallback) by
`infrastructure/config`. Startup fails fast on unsafe values: missing,
placeholder or `< 32`-char secrets, and a wildcard/empty `CORS_ORIGIN`
outside DEV.

| Variable | Role |
| --- | --- |
| `ENVIRONMENT` | `DEV` / `PROD` — DEV extends access-token lifetime and keeps Gin in debug mode |
| `ACCESS_SECRET`, `REFRESH_SECRET` | JWT signing secrets |
| `ENCRYPT_SECRET` | Root secret for field encryption (enc + nonce keys derived via SHA-256) |
| `HOST` | Public host used in password-reset links |
| `HOML_API_URL` | API route prefix |
| `CORS_ORIGIN` | Allowed CORS origin |
| `HANDLER_TIMEOUT` | Per-request timeout (seconds) |
| `MYSQL_*`, `REDIS_*` | Data-source connections |
| `SMTP_*` | Password-reset email sending (skipped if unset) |

## Runtime

Single binary listening on `:8080` (Gin). Shutdown is graceful: SIGINT/SIGTERM
closes the data sources, then gives in-flight requests 5 seconds to finish.
Local orchestration (MySQL, Redis, API) is described in `docker-compose.yml`
and the `Makefile`.

## Repository layout

```
homl-web/
├── db/migrations/           # golang-migrate SQL migrations
├── docs/                    # this documentation
└── src/
    ├── main.go              # config load, DI, HTTP server, graceful shutdown
    └── internal/
        ├── apperror/        # typed application errors → HTTP statuses
        ├── application/     # use-case services (one per aggregate)
        ├── domain/          # aggregates, value objects, Repository ports
        │   ├── category/  event/  masterdata/  user/
        └── infrastructure/
            ├── auth/        # JWT adapter (TokenIssuer, TokenParser)
            ├── config/      # env → Config, fail-fast validation
            ├── crypto/      # deterministic AES-GCM field encryption
            ├── db/          # MySQL + Redis clients
            ├── persistence/ # repository implementations
            ├── ratelimit/   # Redis fixed-window limiter
            └── web/         # Gin router, handlers, middleware
```
