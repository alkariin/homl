# End-to-End Encryption (E2EE) — Specification

Status: **implemented (phase 1) — backend + Flutter client**

Where the pieces live, now that it is built: migration
`db/migrations/000006_e2ee`, `internal/domain/e2ee` (wire format, per-request
mode flag, migration port), `internal/application/e2ee.go`,
`internal/infrastructure/persistence/e2ee.go` (the atomic migration and the
purge), `web.E2EEFlagMiddleware`, and on the client
`homl-ui/lib/helpers/e2ee.dart` plus `homl-ui/lib/pages/e2ee/`. The routes are
listed in [api.md](api.md); the SQL is exercised by
`src/test/dbtest/e2ee_test.go`.

Opt-in feature: the client encrypts tag names, category names and event
descriptions on-device with a key that never leaves the device (except through
an explicit user-initiated recovery-phrase export). The server stores opaque
ciphertext and can no longer read this content. Losing the key means losing
the data — the user is warned and may export a recovery phrase.

This replaces, for opted-in users only, the current **server-side at-rest
encryption** (`src/internal/infrastructure/crypto/crypto.go`: deterministic
AES-256-GCM keyed per-user from `ENCRYPT_SECRET`). Non-opted-in users keep the
current behavior unchanged; both modes coexist.

---

## 1. Goals and non-goals

**Goals**

- Server (and anyone with DB + `ENCRYPT_SECRET` access) cannot read tag names,
  category names or event descriptions of opted-in users.
- Feature is opt-in per user, activated from the app, and reversible.
- Search-by-tags, tag uniqueness and offline cache keep working.
- Optional recovery phrase so a device change does not destroy the data.

**Non-goals (phase 1)**

- Encrypting `Events.date` (stays cleartext; the server keeps sorting and
  date-range filtering). Revisit in phase 2.
- Hiding metadata: row counts, tag↔event graph, categories `kind`/`color`,
  timestamps, user activity patterns remain visible to the server.
- Multi-device sync of the key (the recovery phrase is the manual bridge).
- Key rotation (phase 2).

---

## 2. Cryptography

### 2.1 Keys

| Key | Derivation | Purpose |
|---|---|---|
| `seed` | 16 random bytes (CSPRNG) | Root secret; encodable as a 12-word BIP39 phrase |
| `k_content` | `HKDF-SHA256(seed, info="homl-e2ee:v1:content", 32B)` | AES-256-GCM encryption of values |
| `k_index` | `HKDF-SHA256(seed, info="homl-e2ee:v1:index", 32B)` | HMAC blind indexes |

- Generated on-device when the user enables E2EE (Dart `cryptography` package,
  already a dependency).
- `seed` is stored in `flutter_secure_storage` under key `e2eeMasterKey`
  (Android Keystore-backed EncryptedSharedPreferences / iOS Keychain) — same
  protection level as `refreshToken` and `pinKeypair`. Access is silent once
  the phone is unlocked; the existing app-lock (PIN/biometrics) remains the
  in-app barrier. The key is wiped on logout and on E2EE disable.

### 2.2 Value encryption

- AES-256-GCM, **random 12-byte nonce** per encryption (non-deterministic).
- Wire/storage format: `e2ee:v1:` + base64(nonce ‖ ciphertext ‖ tag).
- The `e2ee:v1:` prefix distinguishes client blobs from legacy server
  ciphertext and allows future format migrations. The server validates the
  prefix and a sane max length on write for E2EE users, nothing more.

### 2.3 Blind index (tags only)

- `tagIndex = hex(HMAC-SHA256(k_index, normalize(tagName))[0:16])` (16 bytes,
  32 hex chars).
- `normalize` is the client-side mirror of the backend `titleCase`
  (`src/internal/application/text.go`), already implemented in
  `homl-ui/lib/helpers/event_search.dart` (`normalizeTagName`).
- Used for: tag uniqueness, server-side tag search, and date-tag reuse.
  Leakage: the server learns equality/frequency of tag usage (not the names).
  This is equivalent to today's deterministic scheme and can later be reduced
  by dropping the index and moving search fully client-side.
- Category names get **no** index: nothing searches or dedups them server-side.

---

## 3. Data model changes

```sql
-- db/migrations/000006_e2ee.up.sql
ALTER TABLE Users ADD COLUMN isE2eeEnabled TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE Users ADD COLUMN e2eeKeyCheck VARCHAR(64) NULL;
ALTER TABLE Tags  ADD COLUMN tagIndex VARCHAR(32) NULL;
ALTER TABLE Tags  ADD UNIQUE KEY tags_index_unique (idCategory, tagIndex);
```

- `tagIndex` is NULL for non-E2EE users; the existing `UNIQUE(idCategory, tag)`
  keeps guarding them. For E2EE users the `tag` column holds non-deterministic
  blobs (never colliding), so `UNIQUE(idCategory, tagIndex)` takes over.
- `e2eeKeyCheck = hex(HMAC-SHA256(k_index, "homl-e2ee:v1:keycheck"))` — lets a
  restoring device verify a typed recovery phrase even if the user has no data
  yet. Set at enable, cleared at disable.

---

## 4. Backend behavior for E2EE users

The application layer branches on `user.isE2eeEnabled` (loaded with the
authenticated user):

| Today (server-side crypto) | E2EE user |
|---|---|
| Encrypt/decrypt via `Encryptor` on every read/write | Pass-through: store and return blobs verbatim |
| `titleCase` normalization on write & search | Skipped (client normalizes before hashing/encrypting) |
| Blacklist check on tag names (`application/tag.go`) | Skipped server-side; enforced client-side before encryption |
| `buildDateTags` derives + encrypts Month/Year tags from `event.date` | Skipped; the client creates/references date tags itself |
| Tag search: encrypt query, match `tag IN (?)` | Match `tagIndex IN (?)` (same synonym-group + `HAVING COUNT` SQL, different column) |
| Tag dedup via deterministic ciphertext equality | Via `tagIndex` equality |

API surface changes:

- `POST /tags`, `PATCH /tags/:id`: accept optional `tagIndex` (required when
  the user is E2EE, rejected otherwise).
- `GET /events?tags=`: for E2EE users the values are 32-hex `tagIndex` strings
  instead of plaintext names.
- `GET /settings`: exposes the read-only `isE2eeEnabled` and `e2eeKeyCheck`,
  so a fresh install knows the mode — and can validate a typed recovery
  phrase — before rendering any data screen (§7). The login/refresh responses
  are unchanged (token pair only); the client reads the settings right after
  authenticating.
- `POST /events`, `PATCH /events/:id`: unchanged shape; `description` carries
  a blob. The client is responsible for creating the Month/Year date tags
  (English names, §6) via `POST /tags` and including their ids in `tagsId`.

---

## 5. Enable / disable migration

Single atomic endpoint, both directions:

```
POST /e2ee/migrate
{
  "direction": "enable" | "disable",
  "keyCheck": "<hex>",                     // enable only
  "categories": [{ "id": 1, "category": "e2ee:v1:..." }, ...],
  "tags":       [{ "id": 7, "tag": "e2ee:v1:...", "tagIndex": "<hex>" }, ...],
  "events":     [{ "id": 42, "description": "e2ee:v1:..." }, ...]
}
```

The endpoint carries the user's whole dataset, so it runs under its own
limits: a 32 MiB body cap and a 60 s handler timeout, instead of the API-wide
1 MiB / `HANDLER_TIMEOUT`.

Server, in **one SQL transaction**: verify every id belongs to the user,
verify the id sets exactly match the user's current rows (any mismatch →
`409 Conflict`, client refetches and retries), update all rows, flip
`isE2eeEnabled`, set/clear `e2eeKeyCheck`, commit. `direction` must differ
from the current flag (otherwise `409`) — this makes retries after a lost
response harmless.

Client flow (enable):

1. `GET /categories` + `GET /events` (server decrypts one last time).
2. Generate `seed`, derive keys, store in secure storage.
3. Offer the recovery phrase screen (12 BIP39 words + QR, user may skip with
   an explicit "risky" acknowledgement).
4. Encrypt everything, compute `tagIndex`es and `keyCheck`, `POST /e2ee/migrate`.
5. On success, re-encrypt the local offline cache (§6). On failure, wipe the
   stored key and surface a retry — nothing changed server-side.

Disable is the mirror image: decrypt locally, send plaintext, server
re-encrypts with its at-rest scheme inside the same transaction, client wipes
the key. UX: a blocking progress screen (download → encrypt → upload); at a
personal-journal scale (5 events/day × 3 years ≈ 5,500 events ≈ 2–3 MB JSON)
the whole flow takes seconds and crypto time is negligible.

Volume guard: if a future feature makes datasets outgrow a single request
(e.g. images), file-like blobs migrate individually *before* this final
atomic metadata commit; the endpoint itself does not change.

---

## 6. Client changes (homl-ui)

- **Crypto helper**: `lib/helpers/e2ee.dart` — the `E2ee` singleton owns the
  seed in secure storage, the HKDF derivation, AES-GCM encrypt/decrypt, the
  blind-index HMAC, the key check and the BIP39 encode/decode.
  `lib/helpers/encryption.dart` stays what it always was: the ed25519
  device-key helpers of the fingerprint factor, unrelated to E2EE.
- **Repositories**: for E2EE users, encrypt on write / decrypt on read at the
  repository layer (`events`, `categories`, `tags`). Filtering by tags sends
  indexes.
- **Offline cache**: `eventsCache` / `categoriesCache` store the **ciphertext**
  payloads verbatim (as today); decryption happens in memory on read, so the
  cache never becomes a second plaintext store.
- **Date tags**: on event create/update, the client ensures the Month/Year
  tags exist (create with ciphertext + index if missing) and references their
  ids — mirroring `buildDateTags` locally (`InsertCubit._buildDateTags`). The
  names are the **English** month names of `lib/helpers/date_tags.dart`
  (`dateTagMonths`), never the device locale: they are keys shared with the
  backend, and both sides must derive the exact same tag. The app translates
  them for display only.
- **Blacklist + normalization**: applied client-side before encryption
  (`E2ee.isBlacklistedTag` over the same `dateTagMonths`, mirroring
  `masterdata.BlacklistedTags()`).
- **Settings UX**: the toggle lives on the Security page of the drawer
  (`lib/pages/account/view/account.dart`), alongside the fingerprint/PIN
  switches which already follow the generate-key + secure-storage pattern.
  Enabling shows: explanation → recovery phrase (optional) → blocking
  migration progress → confirmation. Disabling shows a confirmation warning
  then the reverse migration.

---

## 7. New device / lost key

After login, if the server reports `isE2eeEnabled=true` and no `e2eeMasterKey`
exists locally, the app enters the `e2eeLocked` authentication status and shows
a **blocking screen** (`lib/pages/e2ee/view/e2ee_restore_page.dart`, no data
screens behind it):

- **Enter recovery phrase** → rebuild `seed`, verify against `e2eeKeyCheck`
  (wrong phrase = clear error, no partial state), store the key, proceed. The
  client distinguishes a phrase that fails its own BIP39 checksum (a typo,
  down to which word) from a well-formed phrase belonging to another account.
- **Delete my encrypted data** (destructive, double-confirmed) →
  `POST /e2ee/purge`: in one transaction it deletes the user's events and
  **all** their categories (cascading to tags and event links), reseeds the
  default categories exactly like a fresh registration, and resets
  `isE2eeEnabled` / `e2eeKeyCheck`. The account survives, the data does not.
  `409` if the user is not in E2EE mode. To delete the account *as well*, the
  Security page offers `DELETE /account`
  ([auth-flows.md](auth-flows.md#account-deletion)), which also wipes the
  stored seed on the device.
- **Log out.**

---

## 8. Residual leakage (accepted)

The server still sees: `Events.date` (phase 1 decision), tag/category/event
row counts and ids, the event↔tag graph, `tagIndex` equality patterns
(frequency analysis over small vocabularies is possible), category
`kind`/`color`/`isLocked`, request timing. Accepted trade-offs for keeping
server-side search, uniqueness and date sorting.

---

## 9. Phase 2 candidates

- Encrypt `Events.date` (or coarse-grained `datePeriod` column); move
  sorting/filtering client-side.
- Key rotation (re-encrypt with a new seed; same migration machinery).
- Multi-device via recovery phrase import UX polish, or QR key transfer.
- Images on events: encrypted client-side before upload from day one for E2EE
  users; per-file migration phase for users enabling E2EE afterwards.
- Drop `tagIndex` and go fully client-side search to remove equality leakage.
