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
(`isLocked`) are read-only — `PATCH` and `DELETE` return `403` (see
[default-categories.md](default-categories.md) for the per-kind rules).

| Method | Path | Body | Response |
| --- | --- | --- | --- |
| GET | `/categories` | — | `200` list below |
| POST | `/categories` | `{category, color}` | `201` |
| PATCH | `/categories/:id` | `{category, color}` | `204` |
| DELETE | `/categories/:id` | `{moveTags, deleteEvents?}` | `204` |
| GET | `/categories/:id/usage` | — | `200` usage below |

`color` must be a hex color. `GET /categories` returns:

```json
[
  { "id": 1, "category": "Dates", "color": "#ffff60", "isLocked": true,
    "kind": "date", "tags": [ { "id": 3, "tag": "2024" } ] }
]
```

`DELETE` with `"moveTags": true` moves the category's tags (synonym links
intact) to the user's Other category instead of deleting them. With
`"moveTags": false` the tags are deleted, and `"deleteEvents": true` also
deletes the events whose only non-date tags lived in this category; without
it those events are preserved with their date tags only.

`GET /categories/:id/usage` returns the counts the client shows in its delete
confirmation dialog:

```json
{ "tags": 4, "events": 10, "exclusiveEvents": 2 }
```

`tags` counts the category's tags (synonyms included), `events` the events
referencing them, and `exclusiveEvents` the events that have no other
non-date tag — the ones a plain deletion would leave date-only.

## Tags

All endpoints require auth. Tag names on the masterdata blacklist are
rejected, and the date category is off-limits: it cannot be the target of a
create/update, and its tags cannot be updated or deleted (they are managed by
the backend from the event dates).

**E2EE users** (see [e2ee.md](e2ee.md)): `tag` must be an `e2ee:v1:` blob and
`tagIndex` (32-char lowercase hex blind index) is required; blacklist,
normalization and the date-category restrictions are enforced client-side
instead, so date tags can be created/updated/deleted directly.

`idParentTag` turns the tag into a synonym of another tag of the same
category (one level deep, any category except dates — see
[tag-synonyms.md](tag-synonyms.md)).

| Method | Path | Body | Response |
| --- | --- | --- | --- |
| POST | `/tags` | `{tag, idCategory, idParentTag?, tagIndex?}` | `201` |
| PATCH | `/tags/:id` | `{tag, idCategory, idParentTag?, tagIndex?}` | `204` |
| DELETE | `/tags/:id` | `{deleteEvents?}` (optional) | `204` |
| GET | `/tags/:id/usage` | — | `200` usage below |

Moving a main tag to another category through `PATCH` relocates its synonyms
with it (a synonym always lives in its main tag's category).

`DELETE` on a synonym repoints its events to the main tag. `DELETE` on a main
tag deletes its whole synonym group; `"deleteEvents": true` also deletes the
events whose only non-date tags belonged to the group, otherwise they are
preserved with their date tags only (the body may be omitted entirely).

`GET /tags/:id/usage` returns the counts the client shows in its delete
confirmation dialog:

```json
{ "events": 7, "exclusiveEvents": 3 }
```

`events` counts the events tagged with the tag's synonym group,
`exclusiveEvents` the ones that have no other non-date tag.

## Events

All endpoints require auth. Date tags are added by the backend from `date`;
`tagsId` may be empty. `GET /events` accepts an optional `tags` query filter,
repeated once per tag name (`?tags=2024&tags=July`). The Flutter app no
longer uses this filter — its Search tab filters the cached full list locally
(see homl-ui/README.md) — but the parameter stays supported for API clients.

**E2EE users** (see [e2ee.md](e2ee.md)): `description` must be an `e2ee:v1:`
blob (or empty) and is returned verbatim, the `tags` filter values are blind
indexes instead of names, and the backend does **not** add date tags — the
client creates and attaches its own.

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
| GET | `/settings` | — | `200` `{language, defaultScreen, isE2eeEnabled}` |
| PUT | `/settings` | `{language, defaultScreen}` | `200` updated settings |

`isE2eeEnabled` is read-only here — it is flipped by `POST /e2ee/migrate`
only. A fresh install reads it after login to decide whether to show the
restore-or-purge screen (see [e2ee.md](e2ee.md)).

## End-to-end encryption

All endpoints require auth. See [e2ee.md](e2ee.md) for the full design.

| Method | Path | Body | Response |
| --- | --- | --- | --- |
| POST | `/e2ee/migrate` | see below | `204` |
| POST | `/e2ee/purge` | — | `204` |

### POST /e2ee/migrate

Atomically swaps the user's whole dataset and flips `isE2eeEnabled`, in one
SQL transaction — a failed or interrupted migration changes nothing and is
simply retried. The `id` sets must exactly match the user's stored rows;
any drift (or requesting the direction already in place) returns `409
CONFLICT` and the client refetches and retries. The endpoint accepts bodies
up to 32 MiB and runs under its own 60 s timeout.

```json
{
  "direction": "enable",
  "keyCheck": "<64 hex chars>",
  "categories": [ { "id": 1, "category": "e2ee:v1:…" } ],
  "tags":       [ { "id": 7, "tag": "e2ee:v1:…", "tagIndex": "<32 hex chars>" } ],
  "events":     [ { "id": 42, "description": "e2ee:v1:…" } ]
}
```

- `direction: "enable"` — values are client-encrypted blobs; every tag needs
  its `tagIndex`; `keyCheck` (stored on the user) lets a restoring device
  verify a typed recovery phrase. Malformed values return `400`.
- `direction: "disable"` — values are plaintext; the server re-normalizes
  names, re-encrypts everything with the at-rest scheme and clears the
  indexes and `keyCheck`. Two tags collapsing onto the same name in one
  category return `409` (the client merges them first).

### POST /e2ee/purge

Lost-key escape hatch: deletes every event, tag and category of the user,
reseeds the default categories and disables E2EE — the account survives, the
data does not. Returns `409` if the user is not in E2EE mode. The client
double-confirms before calling.
