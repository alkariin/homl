# Event periods — Design

Status: **backend implemented (PR 1) — client pending (PR 2)**

Every open question is settled; nothing here is waiting on a decision. The
ones that were genuinely open, and their outcome: the card badge **rescales
its unit** (§7.1), **years join the tag blacklist** (§5.5), open periods
carry an **`Ongoing` tag** (§5.6), and the detail sheet **hides the date
tags** like the card does (§7.2). §13 gives the implementation order.

Today an event is a single calendar day (`Events.date`). This design adds a
period: an event may span several days, and may still be running. It touches
the whole chain — migration, domain, application, API, the Flutter model, and
three screens — because the event date is not just displayed: the backend
**derives the Month and Year tags from it**
(`application/event.go:buildDateTags`), and those tags are the only way to
search by date today.

When this ships, fold this document into `homl-web/docs/event-periods.md` and
add it to the README documentation table, the way
[e2ee.md](homl-web/docs/e2ee.md) went from spec to reference doc.

---

## 1. Goals and non-goals

**Goals**

- An event is one of three things: a single day, a closed period, or an open
  ("still ongoing") period.
- The date tags cover every month and year the period is *known* to touch, so
  a trip from 28 June to 5 July is findable under both `June` and `July`.
- Existing events keep their exact current meaning, with no backfill.
- The three states are legal-by-construction in the form: the UI cannot
  produce an invalid combination.
- Year tags stop colliding with user tags: four-digit names join the
  blacklist (§5.5), which the multiplication of year tags makes worth
  closing.
- Open periods stay reachable from the present: a backend-managed `Ongoing`
  tag (§5.6) surfaces "what is going on right now" through the filter the
  user already has.

**Non-goals (phase 1)**

- A server-side date-range filter (`GET /events?from=&to=`). It is the proper
  fix for the open-period tag gap of §5.3 and the reason `Events.date` is
  deliberately cleartext ([e2ee.md](homl-web/docs/e2ee.md) §1) — but it is a
  feature of its own, with its own filter UI. Phase 2.
- A calendar or timeline view with period bands. That is where periods really
  pay off, but nothing of the sort exists yet. Phase 3.
- Times of day. The column stays a MySQL `DATE`; a period is a whole number
  of calendar days.
- Recurring events.

---

## 2. The three states

| State | Meaning | `endDate` | `isOngoing` |
|---|---|---|---|
| Single day | "3 June: dentist" | `NULL` | `false` |
| Closed period | "3 → 18 June: trip to Japan" | set | `false` |
| Open period | "since 3 June: new job" | `NULL` | `true` |

A nullable `endDate` alone cannot carry this: `NULL` would mean both "one day"
and "no end yet". Hence the second, explicit flag. `isOngoing` follows the
column naming already in the schema (`Users.isE2eeEnabled`).

**The end date is inclusive.** "3 → 18 June" means the 18th is part of the
trip. This is the only sane reading on a `DATE` column for a human journal,
and it is what the duration count of §7.1 assumes.

### 2.1 Validation

Enforced in the application layer (a domain invariant, not a payload shape),
via `apperror.NewBadRequest`:

**Where exactly: in `CreateEvent` and `UpdateEvent`, before they call
`prepareEvent`.** This is not a detail. `prepareEvent` short-circuits for
E2EE accounts:

```go
if e2ee.Enabled(ctx) {
    // ... description shape check
    return nil, nil          // ← returns before buildDateTags
}
return e.buildDateTags(...)
```

The intuitive home for period checks is next to `buildDateTags`, since both
read the dates — and that is exactly the wrong place: **every E2EE account
would bypass the validation entirely** and could store `endDate` before
`date`, or `endDate` together with `isOngoing`. The period columns are
cleartext in both modes (§9), so the server can and must validate them for
everyone.

| `endDate` | `isOngoing` | Outcome |
|---|---|---|
| `NULL` | `false` | valid — single day |
| after `date` | `false` | valid — closed period |
| equal to `date` | `false` | **normalized to `NULL`** — see below |
| before `date` | `false` | `400` — "the end date cannot precede the start date" |
| `NULL` | `true` | valid — open period |
| set | `true` | `400` — "an ongoing period cannot have an end date" |

The `endDate == date` normalization matters: without it the same one-day event
has two stored representations, and every display site has to special-case
"3 June – 3 June". Normalizing once on write keeps the rest of the code
honest.

Closing an open period is just a `PATCH` with `endDate` set and `isOngoing`
false — the endpoint is full-state, so no dedicated route is needed.

A period spanning more than 100 years is rejected (`400`). Nothing legitimate
reaches it, and it bounds the tag-expansion loop of §5.1 against a
pathological write.

---

## 3. Data model

### 3.1 Migration

`db/migrations/000007_event_periods`:

```sql
-- up
ALTER TABLE `Events`
  ADD COLUMN `endDate` date NULL AFTER `date`,
  ADD COLUMN `isOngoing` tinyint(1) NOT NULL DEFAULT 0;

-- down
ALTER TABLE `Events`
  DROP COLUMN `isOngoing`,
  DROP COLUMN `endDate`;
```

No backfill: `endDate NULL` + `isOngoing 0` is exactly the current
single-day semantics, so every existing row is already correct. Existing
events also keep their existing date tags, which stay right for a single day.

No index. There is none on `date` either today; one belongs with the phase-2
range filter, keyed `(idUser, date, endDate)`, not before it.

`db/homl.sql` is a Docker volume directory, not a schema dump — the
migrations are the only source of truth to update.

### 3.2 Domain

```
class Event {
    +uint Id
    +string Description
    +time.Time Date
    +*time.Time EndDate
    +bool IsOngoing
}
```

`EndDate` is a pointer so the nullable travels intact all the way to the JSON.
**The `event.Repository` interface does not change** — the new fields ride
inside the `Event` struct — so `test/mocks/events_repo.go` needs no signature
update.

One trap on the read path, found by the e2e test during PR 1: `GetEvents`
rebuilt its `GetEventsResponse` **field by field** (`response.Id = …`,
`response.Date = …`), so the two new columns were written and read back by
the repository and then silently dropped on the way to the wire — the exact
failure §6 warns about for the client's `_decryptEvents`. It now copies the
embedded `Event` whole and only overrides the decrypted description, and a
unit test pins the period fields on the response.

### 3.3 Persistence

`persistence/event.go`:

- `FindEventsWithTags`: add the two columns to the `SELECT` and scan `endDate`
  through a `sql.NullTime`, mirroring the existing `nullStringToString`
  helper for the description.
- `CreateEventWithTags` / `UpdateEventWithTags`: add both columns to the
  `INSERT` / `UPDATE`.

Both columns stay **cleartext**, like `date`, in both modes — see §9.

---

## 4. API

`date` keeps its name and means the start. `startDate` would read better but
buys nothing and churns every client call site.

```
POST /events
PATCH /events/:id
{
  description?: string,
  date: time,
  endDate?: time | null,
  isOngoing?: bool,
  tagsId: []uint
}
```

`GET /events` gains `endDate` (nullable) and `isOngoing` on every item.

`PATCH` is full-state, as it already is for `description`: **omitting
`endDate` clears it**, and omitting `isOngoing` resets it to false. This is
existing behaviour, not a new rule, but it has to be stated in `api.md`
because a client that patches a partial body will silently reopen or
truncate a period.

The realistic way that happens is not a buggy request but **version skew**:
an app build older than this feature does not know the two fields, so every
edit it makes to a period flattens it to a single day. Deploy the client
with, or after, the server — never a new server under an old app that is
still editing events. (Shipping the backend first is fine on its own: no
period exists until a client can create one.)

While in the file: `web.Event` (`event_handler.go:14`) is dead code —
declared, referenced nowhere, and a duplicate of the domain struct. **Delete
it in the same PR** rather than dutifully adding the two new fields to it and
leaving a second, phantom source of truth behind.

---

## 5. Date tags

The interesting part. `buildDateTags` keeps its name — it is referenced from
four places, two of them in the client — but derives the Month and Year tags
from the *whole known* period, through `event.DateTagNames()`: a pure method
on the aggregate, unit-tested without a mock, and the reference the Dart
mirror is written against.

### 5.1 Expansion

Walk month by month from the start to the effective end, collecting month
names and years into a **set**. Order is deliberately unspecified:
`EventsTags` has no order column and `FindEventsWithTags` sorts by `Tags.id`,
so the traversal order never reaches anything — and pinning it would only
manufacture a class of false test failures between the two implementations
(the "over a year" vector of §5.4 starts in March, so a calendar-ordered
assertion and a traversal-ordered one disagree). **Tests compare as sets.**

The set is naturally bounded: at most 12 distinct month names, plus one year
tag per calendar year spanned.

`UpdateEventWithTags` already deletes every `EventsTags` row and reinserts,
so shrinking a period drops the tags it no longer covers. The now-unattached
month tags stay in the `Tags` table — that is already how the Dates category
behaves today, so nothing changes there.

### 5.2 Effective end

- single day → the start date
- closed period → `endDate`
- open period → **the start date only**

### 5.3 Why an open period is tagged from its start alone

An open period has no known end, and the two alternatives are both worse:

- *Expand to today at write time* bakes in an answer that is stale the next
  day, and that only ever grows when the user happens to edit the event. A
  job started in June 2024 would be tagged `2024, 2025, 2026` or just `2024`
  depending on when it was last touched — the same data giving different
  search results is a bug you debug twice.
- *Recompute lazily on read* would turn the date tags into derived values,
  but they are real rows in `Tags` and `EventsTags`. That is a much larger
  architectural change than this feature deserves.

So: the tags cover what is *known*. The consequence, stated plainly as a
limitation — "living in Zurich, since 2019" will **not** appear when filtering
by `2026`. The `Ongoing` tag of §5.6 narrows the gap (that event *is* one
filter away, under `Ongoing`), and the phase-2 range filter closes it
properly, with an interval-overlap predicate where an open period is simply
an end of `+infinity`.

### 5.4 Shared test vectors

This expansion is written **twice**: in Go for normal accounts, and in Dart
for E2EE accounts, which build their own date tags client-side
([e2ee.md](homl-web/docs/e2ee.md) §4). The precedent exists — `dateTagMonths`
and `normalizeTagName` are already mirrored — but two implementations that
must agree exactly is the highest-risk part of this change. Both test suites
implement this same table:

| Case | `date` | `endDate` | `isOngoing` | Expected date tags |
|---|---|---|---|---|
| single day | 2026-06-03 | — | false | `June`, `2026` |
| closed, same month | 2026-06-03 | 2026-06-18 | false | `June`, `2026` |
| closed, two months | 2026-06-28 | 2026-07-05 | false | `June`, `July`, `2026` |
| closed, year boundary | 2025-12-28 | 2026-01-05 | false | `December`, `January`, `2025`, `2026` |
| closed, over a year | 2024-03-01 | 2026-08-31 | false | all 12 months, `2024`, `2025`, `2026` |
| open | 2024-06-03 | — | true | `June`, `2024`, `Ongoing` (§5.6) |

Month names stay English in storage for every user, translated for display
only (`homl-ui/lib/helpers/date_tags.dart`) — unchanged by this design.

### 5.5 Years join the tag blacklist

`BLACKLIST_TAGS` holds the 12 English month names today
(`domain/masterdata/constants.json`), so a user cannot create a tag that
collides with a backend-generated month. Years were never covered: a user can
create `2026` in another category, and `event_search.dart` matches a name
through *every* category carrying it, so filtering `2026` returns both sets.
The expansion of §5.1 multiplies year tags — an event spanning 2024→2026
creates three — so the collision stops being a curiosity.

**Decision: years are blacklisted.** A tag name made of exactly four digits
is refused, whatever the category.

This is a deliberate trade, not a free win: `1984`, `2001` and `1789` become
impossible as user tag names. That cost was weighed and accepted; the rule is
one predicate in one place on each side, so it is cheap to revisit.

Two consequences worth knowing before implementing:

- `BLACKLIST_TAGS` stops being expressible as a JSON array. The 12 month
  names stay in `constants.json`, but the year rule is a **predicate in
  code** — `application/tag.go` gains a four-digit check next to the existing
  list comparison, and `E2ee.isBlacklistedTag`
  (`homl-ui/lib/helpers/e2ee.dart:250`) gains the same one. Third pair of
  mirrored implementations in this feature, after §5.4.
- **The backend-generated tags are not affected.** The server skips the
  blacklist on its own date tags, and the client already lifts it through the
  `isDateTag: true` path in `_outgoingTag`
  (`homl-ui/lib/data/repositories/tags.repository.dart`). Without that
  existing bypass the rule would have blocked E2EE clients from creating
  their own year tags and made this decision unimplementable — it is worth a
  test pinning it.

Existing user tags named like a year are left alone in the table: the rule
does not sweep it. But `validateTag` is shared by `CreateTag` and `UpdateTag`
(`application/tag.go:117` and `:170`) and re-checks the name on every
update, so a pre-existing `1984` becomes **frozen** — it can be deleted, but
giving it a synonym or moving it to another category now returns `400`
because its own name fails validation. A consequence of the decision, stated
so nobody files it as a bug later. If it ever matters, the fix is to skip the
name check when the name is unchanged, not to relax the rule.

### 5.6 The `Ongoing` tag

With §5.3 and §8 as written, an open period is **invisible from the
present**: it is not tagged with the current year, and the timeline files it
under its start date — "living in Zurich, since 2019" sits deep in 2019. That
is one of the most alive facts in a life journal, and nothing surfaces it.

So the Dates category gains a third backend-managed tag, **`Ongoing`**,
attached to every open period next to its start month and year, and dropped
by the rebuild the moment the period is closed (a `PATCH` with `endDate`) —
the same mechanism that already reshapes the month tags. Filtering `Ongoing`
answers "what is going on in my life right now?" with the tool the user
already has.

Every rule is a mirror of what month tags already do:

- Stored as the English word `Ongoing` for every user — a key shared with the
  client, like the month names.
- Reserved: `Ongoing` joins `BLACKLIST_TAGS` in `constants.json` (a list
  entry, unlike the year rule of §5.5) and the Dart blacklist mirror.
- Created through the same bypass as the month tags: server-side in
  `buildDateTagsForPeriod`, client-side in `InsertCubit._buildDateTags` with
  `isDateTag: true` for E2EE accounts. `InsertState.fromEvent` already
  excludes date-category tags from the prefill, so it is never resubmitted as
  a regular tag.
- Hidden on the card (the badge already says `ongoing`) and in the sheet
  (§7.2). It is purely a filter affordance.
- Translated for display like months. `localizedTagName` only knows month
  names today, through `DateFormat.MMMM`; it gains a case for `Ongoing`
  rendered with the `event_ongoing` string. The helper is a pure
  `(name, locale)` function with no `BuildContext`, so it reaches the string
  through the generated `lookupAppLocalizations(Locale(locale))`
  (`app_localizations.dart:973`), not `AppLocalizations.of(context)`.
- Ignored by the deletion counters: `exclusiveEvents` already skips the whole
  date category by `kind`, so it needs no change.

---

## 6. Client plumbing

- `data/models/event.dart`: `DateTime? endDate`, `bool isOngoing`
  (`@JsonKey(defaultValue: false)` so a cached payload written before this
  change still parses). Regenerate `event.g.dart`. Declare `isOngoing` as a
  **`required` constructor parameter, no default** — every field of `Event`
  already is, and this is what turns the next bullet from a silent bug into a
  compile error.
- `data/repositories/events.repository.dart`: send both fields through the
  existing `serializeDate` helper, which already handles the timezone trap
  fixed in #47 — **never** `toUtc()` on a picked date. And **`_decryptEvents`
  must pass the two new fields through**: it rebuilds each `Event(id:,
  description:, date:, tags:)` field by field, so an implementer who forgets
  them ships an app where every E2EE user reads their periods back as single
  days. `required isOngoing` makes the compiler catch that one; `endDate` is
  nullable and escapes it, so a round-trip test on `_decryptEvents` pins it.
- Offline cache: nothing to do. A payload that no longer parses is dropped
  cleanly (`catch (_) → remove`).
- `pages/insert/bloc/insert_state.dart`: `DateTime? endDate` and
  `bool isOngoing`. `copyWith` needs the `clearEndDate: true` escape hatch —
  the same pattern already used for `modal`. `InsertState.fromEvent` prefills
  all three.

---

## 7. Display

### 7.1 Card — a duration badge

The card's date line is centred, 16px bold, `maxLines: 1` with an ellipsis, in
a cell about 250px wide. A full range does not fit there. So the card **keeps
showing the start date unchanged** and gains a small badge next to it:

| State | Badge |
|---|---|
| Single day | none — the majority of events look exactly as they do today |
| Closed period | the duration: `16 days` |
| Open period | `ongoing` |

Layout: a centred `Row` with a `Flexible` date `Text` and the badge after it.
The date keeps ellipsizing, the badge is short enough to always survive.

The badge must **not** reuse `components.Tag` — that would read as a tag and
muddle the tag semantics. It wants its own quieter pill: muted fill, smaller
font, no category colour.

Duration is an inclusive day count (`end - start + 1`), rescaled so the badge
stays readable — `847 days` is noise:

| Span | Unit shown |
|---|---|
| under 31 days | days |
| under 24 calendar months | months |
| 24 calendar months and over | years |

Months are counted on the **calendar**, not on an average day length, and —
this is the part that is easy to get wrong — on the **exclusive** end
`E = endDate + 1 day`, so that the month count agrees with the inclusive day
count:

```
E = endDate + 1 day
months = (E.year - start.year) * 12 + (E.month - start.month)
if E.day < start.day then months = months - 1
years  = months / 12            (integer division)
```

Why the `+ 1 day`: 1 January → 31 December inclusive is a full year, 365
days. Run the formula on `endDate` itself and it yields 11 months; run it on
`E = 1 January next year` and it yields 12. Likewise 1 → 31 March is exactly
one month, not zero. With the exclusive end, the "months" branch can never
produce 0 for a span that reached the 31-day threshold (a same-month span is
at most 30 days inclusive; a next-month span with `E.day < start.day` is
shorter than a month), so no clamp is needed — keep a defensive `max(1, …)`
anyway, it costs nothing. Dividing days by 30.44 would be shorter to write
but drifts against what a human calls "3 months", and the badge is read, not
computed with. Both units floor.

Edge cases the unit test must pin: 1 Jan → 31 Dec = `1 year`; 1 → 31 March =
`1 month`; 1 → 30 March = `30 days`; 1 March 2024 → 28 February 2026 =
`2 years`.

Accepted trade-off of choosing the badge over a collapsed range: the end date
itself is not on the card, only how long the period lasted. The full dates are
one tap away in the detail sheet.

### 7.2 Detail sheet — both dates and the duration

The sheet prints the full `yMMMMEEEEd` date next to two icon buttons; two full
dates will not share that row. Stack them instead:

```
Monday 3 June 2026
→ Thursday 18 June 2026 · 16 days
```

For an open period, the duration runs to today. It is computed at render time
and never stored, so it cannot go stale:

```
Monday 3 June 2026
→ ongoing · since 2 years
```

**A start date in the future drops the "since" part** and shows a bare
`ongoing`, on the card as in the sheet. "I move to Berlin on 1 October, and
it is meant to last" is a legitimate entry, so it is not rejected at
validation — but a duration counted to today would be negative, and
`since -14 days` is a bug on screen. Clamp at zero: no "since" until the
period has actually started.

**The sheet stops showing the date tags.** It renders every tag today
(`event_detail_sheet.dart:114`), where the card already filters them out
through `isDateTag`. That was tolerable with two chips; a three-year period
would put twelve month chips and three year chips — fifteen chips of noise —
right under a header that already prints the full range. Apply the card's
`isDateTag` predicate to the sheet (the `HomeCubit` it receives has the
`dateCategoryIds` to build it). The date tags remain what they always were —
search keys — and the place to see them is the filter suggestions, not the
event.

A single-day event keeps its current single line.

### 7.3 Form — three explicit states

`pages/insert/insert.dart` has one `showDatePicker` today. Add a
`SegmentedButton` with the three states; the end-date field appears only for
"period". A segmented control is worth the extra widget over an
"end date + ongoing checkbox" pair because it makes the invalid combination
of §2.1 **unreachable** — you cannot set an end date and "ongoing" at once.

"Legal-by-construction" has a hole if the flow is naive: a user who selects
"period" and submits before picking an end sends `endDate == null` with
`isOngoing == false` — a perfectly valid **single day**, silently, when they
meant a period. So:

- Selecting "period" **opens the end-date picker immediately**. Cancelling
  the picker reverts the segment to "single day" — the form never rests in a
  "period without an end" state.
- A defensive guard on submit still refuses `period && endDate == null`, for
  whatever path reaches it later.

Three details that bite in practice:

- `firstDate: state.date` on the end picker, so an end before the start is
  simply unpickable rather than an error message after the fact.
- `initialDate: state.endDate ?? state.date` on that same picker. Flutter
  asserts `initialDate` within `[firstDate, lastDate]`; an `initialDate` of
  `DateTime.now()` with a start date in the future is a crash on first open.
- Moving the start date past an already-picked end clears the end date.
  Silently keeping an invalid pair until submit is worse.

### 7.4 Localization

New keys in `app_en.arb`, `app_fr.arb`, `app_de.arb`, then regenerate:

`event_durationDays`, `event_durationMonths`, `event_durationYears` (all
`{count, plural, ...}` — the pattern already exists in
`categories_tagCount`), `event_ongoing`, `event_since`,
`insert_periodSingleDay`, `insert_periodClosed`, `insert_periodOngoing`.

`event_ongoing` does double duty: the badge text, and the display name of the
`Ongoing` tag (§5.6) in the filter suggestions.

Dart's `intl` has no equivalent of ICU's `DateIntervalFormat`, so the
duration and range formatting is a hand-written helper —
`lib/helpers/event_period.dart`, a pure function with its own unit test,
matching the existing `helpers/` convention.

---

## 8. Sorting

Unchanged: start date descending, then id descending
(`eventsService.GetEvents`).

The consequence is worth documenting rather than fixing: an event running from
June to December sits *before* a one-day event in September, because it
started earlier. Floating ongoing events to the top of the list is tempting
and rejected — it breaks the timeline reading that is the whole point of the
list.

---

## 9. E2EE

`endDate` and `isOngoing` stay cleartext, like `date`, for the same reason
already recorded in [e2ee.md](homl-web/docs/e2ee.md) §1: the server keeps
sorting, and the phase-2 range filter needs them readable. The non-goals list
in that document has to be widened from `Events.date` to the period columns —
today it names one column and would be quietly wrong.

E2EE clients build their own date tags, so they carry the §5.1 expansion
**and** the §5.2 open-period rule. §5.4 is the guard against the two
implementations drifting.

---

## 10. Tests

**Go**

- `internal/application/event_test.go` — the §2.1 validation matrix, the
  `endDate == date` normalization, the §5.4 expansion vectors, **and the same
  matrix run with E2EE enabled** — that last one is what fails today if the
  checks drift back behind the `prepareEvent` short-circuit (§2.1).
- `internal/application/tag_test.go` — a four-digit tag name is refused
  (§5.5), next to the existing month-name cases.
- `test/dbtest/` — round-trip of all three states, including `NULL` handling.
- `test/e2e/e2e_test.go` — create a closed period, close an open one via
  `PATCH`, assert the date tags attached — including that `Ongoing` is there
  while the period is open and **gone once it is closed** (§5.6).
- `internal/infrastructure/web/router_test.go` — the two fields parsed and
  forwarded on `POST` and `PATCH` (`null` and omitted `endDate` alike), and a
  service `400` relayed to the client with its message. The invariants
  themselves belong to the application layer and are tested there — the
  router tests run against mocked services.

**Dart**

- `test/event_period_test.dart` (new) — the duration thresholds of §7.1
  with its four named edge cases (1 Jan → 31 Dec is `1 year`, 1 → 31 March is
  `1 month`), and the §5.4 expansion vectors compared as sets.
- `test/events_repository_date_test.dart` — a null `endDate` serializes to
  null, not to an epoch; and a `_decryptEvents` round-trip keeps `endDate`
  and `isOngoing` (§6).
- `test/event_card_test.dart` — badge present for a period, **absent** for a
  single day, `ongoing` for an open one, and no "since" on a future start
  (§7.2).
- `test/event_detail_sheet_test.dart` — the stacked two-date layout, and the
  date-category tags (months, years, `Ongoing`) **not** rendered as chips.
- `test/insert_cubit_test.dart` — the three states in `InsertState`,
  `clearEndDate`, the submit guard refusing `period && endDate == null`; plus
  a widget test on `insert.dart` for the open-picker-on-select flow and its
  revert on cancel (§7.3).
- `test/date_tags_test.dart` — `Ongoing` translates through `event_ongoing`,
  month names still translate through `intl` (§5.6).
- `test/e2ee_test.dart` — `isBlacklistedTag('2026')` is true, and a year tag
  still goes through when created as a date tag (§5.5) — the bypass this
  decision rests on.

---

## 11. Documentation to update in the same PR

| Document | Change |
|---|---|
| `homl-web/docs/api.md` | *Events*: `endDate` / `isOngoing` in the bodies and the `GET` response, the two `400`s, the full-state `PATCH` warning. *Tags*: "names on the masterdata blacklist are rejected" is no longer the whole story — four-digit names are refused by rule |
| `homl-web/docs/domain-model.md` | the `Event` class in the mermaid diagram; and the masterdata note — `constants.json` no longer holds the whole blacklist, the year rule lives in code |
| `homl-web/docs/e2ee.md` | §1 non-goals widened to the period columns; §4 client-built date tags now span a period |
| `homl-web/docs/default-categories.md` | "tags are the month and year of the event" becomes "of the months and years the event's period covers", plus the open-period rule and the `Ongoing` tag as the third backend-managed name; the blacklist line now covers `Ongoing` and four-digit names, not only the 12 months |
| `homl-web/TESTING.md` | an *Event periods* section, the way every feature lists what covers it at each layer |
| `homl-ui/README.md` | the duration badge, the three-state form |

---

## 12. Phasing

1. **This document** — the three states end to end: migration, domain, API,
   validation, tag expansion in Go *and* Dart, `Ongoing` tag, card badge,
   detail sheet, form.
2. **Server-side range filter** `GET /events?from=&to=` with interval-overlap
   semantics. Closes the §5.3 open-period gap and is the reason the period
   columns are cleartext.
3. **Calendar / timeline view** with period bands.

---

## 13. Implementation order

Two pull requests, backend first. The backend can ship alone — no period
exists until a client can create one (§4) — and the split keeps each review
readable. Within each, the order below is the one where every step is
compilable and testable on its own before the next starts.

**PR 1 — `homl-web`**

1. Migration `000007_event_periods` (§3.1). Run it against the dev database
   before touching Go, so the persistence tests have the columns.
2. Domain: the two fields on `event.Event` (§3.2). Compiles; nothing reads
   them yet.
3. Persistence: `SELECT` + `sql.NullTime` scan, `INSERT`, `UPDATE` (§3.3).
   `dbtest` round-trip of the three states.
4. Application, in this order: the validation matrix in `CreateEvent` /
   `UpdateEvent` **before** `prepareEvent` (§2.1), with its test run twice,
   E2EE off and on; then `event.DateTagNames()` on the aggregate with the
   §5.4 vectors as set comparisons and the `Ongoing` tag (§5.6), and
   `buildDateTags` reading it.
5. Blacklist: `Ongoing` into `constants.json`; the four-digit predicate into
   `validateTag` (§5.5); `tag_test.go` cases for both.
6. Handler: the two body fields on `POST` / `PATCH`; delete `web.Event`
   (§4). `router_test.go` for the shape and the two `400`s; `e2e_test.go` for
   the open → closed transition.
7. Docs from §11 — `api.md`, `domain-model.md`, `e2ee.md`,
   `default-categories.md`, `TESTING.md` — in the same PR, per the repo rule.

**PR 2 — `homl-ui`**

1. Model: fields + `required isOngoing` + codegen (§6). `_decryptEvents`
   passes them through; its round-trip test.
2. Repository: both fields through `serializeDate` on create and update.
3. Blacklist mirror and date tags: `isBlacklistedTag` gains `Ongoing` and the
   four-digit rule; `InsertCubit._buildDateTags` expands over the period and
   adds `Ongoing` (§5.1, §5.6), with the §5.4 vectors as set comparisons.
4. Helper `lib/helpers/event_period.dart`: duration with the exclusive-end
   formula and its four edge cases (§7.1); `localizedTagName` gains
   `Ongoing` (§5.6).
5. Localization keys in the three `.arb` files, regenerate (§7.4).
6. Form: `InsertState` fields and `clearEndDate`, the segmented control, the
   open-picker-on-select flow, the `initialDate` fix, the submit guard (§7.3).
7. Card badge (§7.1), then the sheet: stacked dates, "since" with its future
   clamp, date tags hidden (§7.2).
8. `homl-ui/README.md` (§11).

Once both are merged: move this file to `homl-web/docs/event-periods.md`,
flip its status to *implemented*, and add it to the README table.
