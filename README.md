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

**Android without Flutter:** every [release](https://github.com/alkariin/homl/releases)
carries a signed APK, which Obtainium can keep up to date — see
[deployment.md §5](homl-web/docs/deployment.md#5-building-the-clients).

**Backend without building:** every release also publishes the
`ghcr.io/alkariin/homl-back` image, which carries its own migrations: a compose
file and a `.env` on the server, no checkout — see
[deployment.md §3](homl-web/docs/deployment.md#without-building-the-published-image).

**Self-hosting?** Before opening the instance to anyone, put
`homl-web/scripts/backup.sh` in root's crontab and rehearse one restore with
`scripts/restore.sh` — see [deployment.md §7](homl-web/docs/deployment.md#7-backups).
Once the accounts it is meant for exist, set `REGISTRATION_OPEN=false` so
nobody else can sign up — see [deployment.md §3](homl-web/docs/deployment.md#create-the-accounts-then-close-sign-ups).

App icons and native splash screens are generated from the logo — see
[`homl-ui/tool/icons/README.md`](homl-ui/tool/icons/README.md) to regenerate them.

## Documentation

| Document | Content |
|---|---|
| [homl-web/docs/architecture.md](homl-web/docs/architecture.md) | Backend layering (hexagonal), ports & adapters, request lifecycle, configuration |
| [homl-web/docs/domain-model.md](homl-web/docs/domain-model.md) | Aggregates, relations and persistence ports |
| [homl-web/docs/api.md](homl-web/docs/api.md) | HTTP reference: every route, body, status code and error shape |
| [homl-web/docs/auth-flows.md](homl-web/docs/auth-flows.md) | Login, refresh with PIN/fingerprint, the client session offline, password reset, logout, account deletion |
| [homl-web/docs/e2ee.md](homl-web/docs/e2ee.md) | End-to-end encryption: crypto, wire format, migration, recovery |
| [homl-web/docs/offline-sync.md](homl-web/docs/offline-sync.md) | Writing offline: the outbox, the sync, conflicts, what stays online-only |
| [homl-web/docs/data-export.md](homl-web/docs/data-export.md) | Export and import of a user's data: the file format, password protection, the merge rules |
| [homl-web/docs/deployment.md](homl-web/docs/deployment.md) | Self-hosting: secrets, TLS, reverse proxy, email, backups, upgrades |
| [homl-web/docs/default-categories.md](homl-web/docs/default-categories.md) | The three seeded categories and their rules |
| [homl-web/docs/tag-synonyms.md](homl-web/docs/tag-synonyms.md) | Synonyms: rules, lifecycle, client-side matching |
| [homl-web/docs/tag-groups.md](homl-web/docs/tag-groups.md) | Tag groups: shortcuts expanding into their tags, rules and lifecycle |
| [homl-web/docs/event-periods.md](homl-web/docs/event-periods.md) | Event periods: single day, closed or open period; date tags over the period and the `Ongoing` tag; the card badge, the sheet, the form and the timeline |
| [homl-web/TESTING.md](homl-web/TESTING.md) | Backend test layers and how to run them |
| [homl-ui/README.md](homl-ui/README.md) | Flutter setup, device builds, and the UI behaviours worth knowing |

## Tech stack

| Layer | Technology |
|---|---|
| API | Go 1.26, Gin, golang-jwt (built on `golang:1.27-alpine`) |
| Database | MySQL 8.4 |
| Cache / sessions | Redis |
| Frontend | Flutter 3, Bloc, Dio |
| Infrastructure | Docker Compose |
