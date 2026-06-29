# HOML — History of My Life

A self-hosted personal journal app. Record life events, link them to people and categories, and browse your own history.

## Architecture

```
homl/
├── homl-web/   Go REST API  (Gin · MySQL · Redis · JWT)
└── homl-ui/   Flutter app  (iOS · Android · Web)
```

The Flutter app communicates with the Go backend over HTTP/JSON. Authentication uses short-lived JWT access tokens and long-lived refresh tokens stored in Redis.

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

## Tech stack

| Layer | Technology |
|---|---|
| API | Go 1.23, Gin, golang-jwt |
| Database | MySQL 8.4 |
| Cache / sessions | Redis |
| Frontend | Flutter 3, Bloc, Dio |
| Infrastructure | Docker Compose |
