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
| POST | `/resetPassword` | — | 5/hour ¹ |
| POST | `/confirmResetPassword` | — | 5/hour ¹ |
| POST | `/challenge` | refresh token | 30/min |
| PUT | `/secureAuth` | ✔ | — |
| DELETE | `/account` | ✔ | 10/min ² |

¹ Both reset endpoints share a single per-IP budget, so a full reset round trip
spends two of the five hourly requests.

² `DELETE /account` shares the per-IP budget of `/login` and `/registration`:
it takes a password, so it must not become a brute-force oracle.

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

→ `204` always (anti-enumeration), `422` if `username` is not an email. If the
account exists, a single-use 6-digit code (15 min TTL) is emailed in the user's
stored language. A second request for the same account within 1 minute is
silently dropped (per-user cooldown), still returning `204`. The email is sent
outside the request, so neither the status nor the latency reveals whether the
address is known — see `docs/auth-flows.md`.

### POST /confirmResetPassword

Unauthenticated: the code emailed above is carried in the body, alongside the
username it was issued for.

```json
{ "username": "a@b.c", "code": "123456", "password": "newSecret123" }
```

→ `200` fresh token pair — `422` if `code` is not 6 digits or the password
fails validation, `401` `RESET_CODE_INVALID` for an unknown username, a wrong,
expired or already-consumed code. All of those share one error so the endpoint
cannot enumerate accounts. Five wrong guesses destroy the code and a new one
must be requested.

Changing the password invalidates every existing session for that user.

### POST /challenge

Returns a one-time challenge to be signed by the device key (fingerprint
flow). The refresh token is carried in the request body.

```json
{ "refresh_token": "..." }
```

→ `200` `"<challenge>"` (base64url string).

The body is a **bare JSON string**, quotes included. Clients must JSON-decode
it before signing: the server verifies the signature against the decoded
value, so signing the raw body fails every refresh with `401`.

### PUT /secureAuth

Enables/disables the pin or fingerprint factor. Pin and fingerprint are
mutually exclusive; `pin` requires `pkey`; `pkey` is only accepted while a
factor is enabled.

```json
{ "isFingerprintEnabled": false, "isPinEnabled": true, "pin": "1234", "pkey": "base64" }
```

→ `200` `{ "isFingerprintEnabled": bool, "isPinEnabled": bool }` — `400` on an
inconsistent combination.

### DELETE /account

Deletes the account for good, together with every category, tag and event it
owns (the schema cascades from the `Users` row, so nothing is left behind).
Every session and any pending password-reset code are revoked first. There is
no grace period, no soft delete and no confirmation email.

The password is re-entered by the client and re-checked here: a stolen access
token must not be enough to destroy the data. The client double-confirms and
wipes its own state afterwards — including the E2EE seed, which is the one
thing logout deliberately keeps.

```json
{ "password": "..." }
```

→ `204` — `401` if the password does not match — `422` if it is missing or too
short — `404` if the account is already gone.

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
    "kind": "date", "tags": [ { "id": 3, "tag": "2024", "idParentTag": null } ] }
]
```

`idParentTag` is the synonym link (`null` on a main tag, see
[tag-synonyms.md](tag-synonyms.md)).

`DELETE` with `"moveTags": true` moves the category's tags (synonym links
intact) to the user's Other category instead of deleting them. With
`"moveTags": false` the tags are deleted, and `"deleteEvents": true` also
deletes every event tagged with one of them, whatever other tags it carries;
without it those events are preserved, only the tags are removed from them
(the ones that had no other non-date tag are left date-only).

`GET /categories/:id/usage` returns the counts the client shows in its delete
confirmation dialog:

```json
{ "tags": 4, "events": 10, "exclusiveEvents": 2 }
```

`tags` counts the category's tags (synonyms included), `events` the events
referencing them (the ones `deleteEvents` would delete), and
`exclusiveEvents` the events that have no other non-date tag — the ones a
deletion that keeps the events would leave date-only.

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
tag deletes its whole synonym group; `"deleteEvents": true` also deletes every
event tagged with the group, whatever other tags it carries, otherwise those
events are preserved and only the tag is removed from them (the body may be
omitted entirely).

`GET /tags/:id/usage` returns the counts the client shows in its delete
confirmation dialog:

```json
{ "events": 7, "exclusiveEvents": 3 }
```

`events` counts the events tagged with the tag's synonym group (the ones
`deleteEvents` would delete), `exclusiveEvents` the ones that have no other
non-date tag — the ones a deletion that keeps the events would leave
date-only.

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

`GET /events` returns the events newest first (by `date` descending, most
recently created first for the same day), so an event created for a past day
or whose date was edited lands at its chronological slot, not at its creation
slot:

```json
[
  { "id": 1, "description": "…", "date": "2026-07-05T00:00:00Z",
    "tags": [ { "id": 3, "tag": "…", "idCategory": 2, "idParentTag": null } ] }
]
```

`date` is a calendar day, not an instant: the column is a MySQL `DATE`, so
the time part of the RFC 3339 value is truncated (`2026-08-31T22:00:00Z` is
stored as `2026-08-31`). Clients must send the picked day as UTC midnight
(`YYYY-MM-DDT00:00:00Z`, the same shape `GET /events` returns) and must not
convert a local-midnight date to UTC — east of UTC that lands on the previous
day. The month/year date tags are derived from that stored day.

Tags carry only `idCategory` (no category join): the client already holds the
categories from `GET /categories`. `idParentTag` lets the client resolve a
synonym to its group; `tagIndex` is added for E2EE users and omitted
otherwise.

## Settings

All endpoints require auth.

| Method | Path | Body | Response |
| --- | --- | --- | --- |
| GET | `/settings` | — | `200` `{language, defaultScreen, isE2eeEnabled, e2eeKeyCheck?}` |
| PUT | `/settings` | `{language, defaultScreen}` | `200` updated settings |

`isE2eeEnabled` and `e2eeKeyCheck` are read-only here — they are set by
`POST /e2ee/migrate` only, and `PUT /settings` ignores them in the body. A
fresh install reads `isE2eeEnabled` after login to decide whether to show the
restore-or-purge screen, and `e2eeKeyCheck` (omitted when unset) is what lets
that screen validate a typed recovery phrase (see [e2ee.md](e2ee.md)).

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
