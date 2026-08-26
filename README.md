# HOML — History of My Life

A self-hosted personal journal app. Record life events, link them to people and categories, and browse your own history.

## Architecture

```
homl/
├── homl-web/   Go REST API  (Gin · MySQL · Redis · JWT)
└── homl-ui/   Flutter app  (iOS · Android · Web)
```

The Flutter app communicates with the Go backend over HTTP/JSON. Authentication uses short-lived JWT access tokens and long-lived refresh tokens stored in Redis, optionally guarded by a second factor (PIN or fingerprint). An account can also be switched to opt-in end-to-end encryption, after which the server only ever stores ciphertext it cannot read.

## Quick start

### Backend

```bash
cd homl-web
cp .env.example .env        # fill in secrets
make dev                    # build image · start stack · migrate · seed
```

API available at `http://localhost:8080`. Demo account: `demo@homl.local / Demo1234!`

### Frontend

```bash
cd homl-ui
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api
```

See each sub-project's README for full setup.

App icons and native splash screens are generated from the logo — see
[`homl-ui/tool/icons/README.md`](homl-ui/tool/icons/README.md) to regenerate them.

## Documentation

| Document | Content |
|---|---|
| [homl-web/docs/architecture.md](homl-web/docs/architecture.md) | Backend layering (hexagonal), ports & adapters, request lifecycle, configuration |
| [homl-web/docs/domain-model.md](homl-web/docs/domain-model.md) | Aggregates, relations and persistence ports |
| [homl-web/docs/api.md](homl-web/docs/api.md) | HTTP reference: every route, body, status code and error shape |
| [homl-web/docs/auth-flows.md](homl-web/docs/auth-flows.md) | Login, refresh with PIN/fingerprint, password reset, logout, account deletion |
| [homl-web/docs/e2ee.md](homl-web/docs/e2ee.md) | End-to-end encryption: crypto, wire format, migration, recovery |
| [homl-web/docs/deployment.md](homl-web/docs/deployment.md) | Self-hosting: secrets, TLS, reverse proxy, email, backups, upgrades |
| [homl-web/docs/default-categories.md](homl-web/docs/default-categories.md) | The three seeded categories and their rules |
| [homl-web/docs/tag-synonyms.md](homl-web/docs/tag-synonyms.md) | Synonyms: rules, lifecycle, client-side matching |
| [homl-web/TESTING.md](homl-web/TESTING.md) | Backend test layers and how to run them |
| [homl-ui/README.md](homl-ui/README.md) | Flutter setup, device builds, and the UI behaviours worth knowing |

## Tech stack

| Layer | Technology |
|---|---|
| API | Go 1.25, Gin, golang-jwt (built on `golang:1.26-alpine`) |
| Database | MySQL 8.4 |
| Cache / sessions | Redis |
| Frontend | Flutter 3, Bloc, Dio |
| Infrastructure | Docker Compose |
