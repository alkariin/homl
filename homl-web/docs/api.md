# API reference

All routes live under the prefix configured by `HOML_API_URL` and are served
on port 8080. Source of truth: `src/internal/infrastructure/web/router.go` and
the handlers next to it.

## Conventions

- **Auth** — protected endpoints require `Authorization: Bearer <access_token>`
  (see [auth-flows.md](auth-flows.md)). The middleware rejects invalid or
  revoked sessions with `401`.
- **Rate limits** — public auth endpoints are throttled per IP (fixed window,
  Redis-backed); exceeding a limit returns `429 TOO_MANY_REQUESTS`.
- **Timeout** — every request is bounded by `HANDLER_TIMEOUT` seconds; a
  handler that overruns returns `503 SERVICE_UNAVAILABLE`.
- **Errors** — all errors share one shape:

  ```json
  { "error": { "type": "AUTHORIZATION", "message": "Not authorized" } }
  ```

  | Type | HTTP status |
  | --- | --- |
  | `AUTHORIZATION` | 401 |
  | `BAD_REQUEST` | 400 |
  | `CONFLICT` | 409 |
  | `NOT_FOUND` | 404 |
  | `STATUS_FORBIDDEN` | 403 |
  | `STATUS_UNPROCESSABLE_ENTITY` | 422 |
  | `TOO_MANY_REQUESTS` | 429 |
  | `PAYLOAD_TOO_LARGE` | 413 |
  | `UNSUPPORTED_MEDIA_TYPE` | 415 |
  | `SERVICE_UNAVAILABLE` | 503 |
  | `INTERNAL` | 500 |

  Unexpected internal errors are replaced by a generic `INTERNAL` so nothing
  leaks; the original error is only logged.

## Auth & account

| Method | Path | Auth | Rate limit |
| --- | --- | --- | --- |
| POST | `/registration` | — | 10/min |
| POST | `/login` | — | 10/min |
| POST | `/logout` | ✔ | — |
| POST | `/refresh` | refresh token | 30/min |
| PUT | `/password` | ✔ | — |
| POST | `/resetPassword` | — | 5/hour |
| POST | `/confirmResetPassword` | reset token | 5/hour |
| POST | `/challenge` | refresh token | 30/min |
| PUT | `/secureAuth` | ✔ | — |

### POST /registration

Creates the account and its default categories, returns a session.
`username` must be an email, `password` at least 8 characters, `language` one
of `fr`, `de`, `en`.

```json
{ "username": "a@b.c", "password": "secret123", "language": "fr" }
```

→ `200` `{ "access_token": "...", "refresh_token": "..." }` — `409` if the
username already exists, `422` on validation failure.

### POST /login

```json
{ "username": "a@b.c", "password": "secret123" }
```

→ `200` token pair — `401` on any credential failure (no distinction leaked).

### POST /logout

Empty body. Revokes the access session and clears any pending challenge.
→ `204`.

### POST /refresh

Rotates the token pair. `pin` or `signature` is **required** by the server
once the matching factor is enabled on the account; a `pin` must always be
accompanied by a `signature`.

```json
{ "refresh_token": "...", "signature": "base64?", "pin": "1234?" }
```

→ `201` token pair — `401` on invalid/rotated token, missing factor, bad
signature or locked pin.

### PUT /password

```json
{ "oldPassword": "...", "newPassword": "..." }
```

→ `200` fresh token pair — `401` if the old password does not match.

### POST /resetPassword

```json
{ "username": "a@b.c" }
```

→ `204` always (anti-enumeration). If the account exists, a single-use reset
link (15 min TTL) is emailed.

### POST /confirmResetPassword

The reset token from the emailed link goes in the `Authorization: Bearer`
header; the body carries only the new password.

```json
{ "password": "newSecret123" }
```

→ `200` fresh token pair — `401` if the token is unknown, expired or already
used.

### POST /challenge

Returns a one-time challenge to be signed by the device key (fingerprint
flow). The refresh token is carried in the request body.

```json
{ "refresh_token": "..." }
```

→ `200` `"<challenge>"` (base64url string).

### PUT /secureAuth

Enables/disables the pin or fingerprint factor. Pin and fingerprint are
mutually exclusive; `pin` requires `pkey`; `pkey` is only accepted while a
factor is enabled.

```json
{ "isFingerprintEnabled": false, "isPinEnabled": true, "pin": "1234", "pkey": "base64" }
```

→ `200` `{ "isFingerprintEnabled": bool, "isPinEnabled": bool }` — `400` on an
inconsistent combination.

## Categories

All endpoints require auth. A category groups tags; locked categories
(`isLocked`) are system-managed.

| Method | Path | Body | Response |
| --- | --- | --- | --- |
| GET | `/categories` | — | `200` list below |
| POST | `/categories` | `{category, color}` | `201` |
| PATCH | `/categories/:id` | `{category, color}` | `204` |
| DELETE | `/categories/:id` | `{moveTags}` | `204` |

`color` must be a hex color. `GET /categories` returns:

```json
[
  { "id": 1, "category": "Dates", "color": "#fff", "isLocked": true,
    "tags": [ { "id": 3, "tag": "2024" } ] }
]
```

`DELETE` with `"moveTags": true` moves the category's tags instead of
deleting them with the category.

## Tags

All endpoints require auth. Tag names on the masterdata blacklist are
rejected.

| Method | Path | Body | Response |
| --- | --- | --- | --- |
| POST | `/tags` | `{tag, idCategory}` | `201` |
| PATCH | `/tags/:id` | `{tag, idCategory}` | `204` |
| DELETE | `/tags/:id` | — | `204` |

## Persons

All endpoints require auth. Nicknames are stored as tags attached to the
person; when updating, an existing nickname must carry its `id`.

| Method | Path | Body | Response |
| --- | --- | --- | --- |
| GET | `/persons` | — | `200` list below |
| POST | `/persons` | `{firstname, lastname, nicknames?: string[]}` | `201` |
| PATCH | `/persons/:id` | `{firstname, lastname, nicknames?: [{id?, nickname}]}` | `204` |
| DELETE | `/persons/:id` | — | `204` |

`GET /persons` returns:

```json
[
  { "id": 1, "firstname": "Ada", "lastname": "Lovelace",
    "nicknames": [ { "id": 7, "nickname": "Ada L." } ] }
]
```

## Events

All endpoints require auth. Date tags are added by the backend from `date`;
`tagsId` may be empty. `GET /events` accepts an optional `tags` query filter,
repeated once per tag name (`?tags=2024&tags=July`).

| Method | Path | Body / query | Response |
| --- | --- | --- | --- |
| GET | `/events` | `?tags=<name>&tags=<name>` (optional) | `200` list below |
| POST | `/events` | `{description?, date, tagsId: uint[]}` | `201` |
| PATCH | `/events/:id` | `{description?, date, tagsId: uint[]}` | `204` |
| DELETE | `/events/:id` | — | `204` |

`GET /events` returns:

```json
[
  { "id": 1, "description": "…", "date": "2026-07-05T00:00:00Z",
    "tags": [ { "id": 3, "tag": "…", "idCategory": 2 } ] }
]
```

Tags carry only `idCategory` (no category join): the client already holds the
categories from `GET /categories`.

## Settings

All endpoints require auth.

| Method | Path | Body | Response |
| --- | --- | --- | --- |
| GET | `/settings` | — | `200` `{language, defaultScreen, isFingerprintEnabled, isPinEnabled}` |
| PUT | `/settings` | `{language, defaultScreen}` | `200` updated settings |

The second-factor flags are read-only here — they are managed through
`PUT /secureAuth`.
