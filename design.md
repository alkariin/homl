# Event periods — Design

Status: **draft — not implemented**

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

---

## 5. Date tags

The interesting part. `buildDateTags` becomes `buildDateTagsForPeriod` and
derives the Month and Year tags from the *whole known* period.

### 5.1 Expansion

Walk month by month from the start to the effective end, collecting month
names and years into an **ordered set, first-seen wins**. That traversal order
is the natural implementation in both languages and makes the expected tag
list deterministic for the tests of §5.4.

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
by `2026`. That gap is what the phase-2 range filter closes properly, with an
interval-overlap predicate where an open period is simply an end of
`+infinity`.

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
| open | 2024-06-03 | — | true | `June`, `2024` |

Month names stay English in storage for every user, translated for display
only (`homl-ui/lib/helpers/date_tags.dart`) — unchanged by this design.

---

## 6. Client plumbing

- `data/models/event.dart`: `DateTime? endDate`, `bool isOngoing`
  (`@JsonKey(defaultValue: false)` so a cached payload written before this
  change still parses). Regenerate `event.g.dart`.
- `data/repositories/events.repository.dart`: send both fields through the
  existing `serializeDate` helper, which already handles the timezone trap
  fixed in #47 — **never** `toUtc()` on a picked date.
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

| Span | Unit |
|---|---|
| under 31 days | days |
| under 24 months | months (floored, minimum 1) |
| 24 months and over | years (floored) |

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

A single-day event keeps its current single line.

### 7.3 Form — three explicit states

`pages/insert/insert.dart` has one `showDatePicker` today. Add a
`SegmentedButton` with the three states; the end-date field appears only for
"period". A segmented control is worth the extra widget over an
"end date + ongoing checkbox" pair because it makes the invalid combination
of §2.1 **unreachable** — you cannot set an end date and "ongoing" at once.

Two details that bite in practice:

- `firstDate: state.date` on the end picker, so an end before the start is
  simply unpickable rather than an error message after the fact.
- Moving the start date past an already-picked end clears the end date.
  Silently keeping an invalid pair until submit is worse.

### 7.4 Localization

New keys in `app_en.arb`, `app_fr.arb`, `app_de.arb`, then regenerate:

`event_durationDays`, `event_durationMonths`, `event_durationYears` (all
`{count, plural, ...}` — the pattern already exists in
`categories_tagCount`), `event_ongoing`, `event_since`,
`insert_periodSingleDay`, `insert_periodClosed`, `insert_periodOngoing`.

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
  `endDate == date` normalization, the §5.4 expansion vectors.
- `test/dbtest/` — round-trip of all three states, including `NULL` handling.
- `test/e2e/e2e_test.go` — create a closed period, close an open one via
  `PATCH`, assert the date tags attached.
- `internal/infrastructure/web/router_test.go` — payload shape, `400` on the
  two invalid combinations.

**Dart**

- `test/event_period_test.dart` (new) — the duration rescaling thresholds of
  §7.1 and the §5.4 expansion vectors.
- `test/events_repository_date_test.dart` — a null `endDate` serializes to
  null, not to an epoch.
- `test/event_card_test.dart` — badge present for a period, **absent** for a
  single day, `ongoing` for an open one.
- `test/event_detail_sheet_test.dart` — the stacked two-date layout.

---

## 11. Documentation to update in the same PR

| Document | Change |
|---|---|
| `homl-web/docs/api.md` | `endDate` / `isOngoing` in the bodies and the `GET` response, the two `400`s, the full-state `PATCH` warning |
| `homl-web/docs/domain-model.md` | the `Event` class in the mermaid diagram |
| `homl-web/docs/e2ee.md` | §1 non-goals widened to the period columns; §4 client-built date tags now span a period |
| `homl-web/docs/default-categories.md` | "tags are the month and year of the event" becomes "of the months and years the event's period covers", plus the open-period rule |
| `homl-ui/README.md` | the duration badge, the three-state form |

---

## 12. Phasing

1. **This document** — the three states end to end: migration, domain, API,
   validation, tag expansion in Go *and* Dart, card badge, detail sheet, form.
2. **Server-side range filter** `GET /events?from=&to=` with interval-overlap
   semantics. Closes the §5.3 open-period gap and is the reason the period
   columns are cleartext.
3. **Calendar / timeline view** with period bands.
