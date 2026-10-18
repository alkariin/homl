# Offline writes and sync

How the Flutter client (`homl-ui/lib/data/sync/`) lets a user write while the
server is out of reach — a phone away from the home network cannot see a NAS
on the LAN — and sends everything once it answers again. The server stays the
judge of every write: the client only replays the regular REST calls, so the
Go rules (period validation, tag uniqueness, synonyms, date tags) apply to
offline writes exactly as to online ones.

Related: [auth-flows.md](auth-flows.md) ("Client session": how the session
survives without the server), [api.md](api.md) (the `clientId` of
`POST /events` and `POST /categories`, `dataGeneration` in the settings),
[e2ee.md](e2ee.md) §6.

## What works offline

| Offline | Online only (a clear "server unreachable") |
| --- | --- |
| browsing and searching the data saved on the device | settings, PIN, fingerprint, password, account |
| creating, editing and deleting events | enabling / disabling end-to-end encryption |
| creating, renaming, moving and deleting tags, synonyms included | importing a file |
| creating, editing and deleting categories and tag groups | |

Anything created offline can be used, changed or deleted at once, before the
server has it: a tag in a category created offline, a group of tags created
offline, an event using them.

**Deleting "with its events" offline** deletes the events this device shows,
one ordinary event deletion each, then the tag or category alone (keeping
whatever events remain). Sent as it is, the server would delete every event
carrying the tag when it gets the request — including events added on
another device meanwhile, which nobody here ever saw. Split this way, only
what was on screen goes, and an event edited elsewhere meanwhile is kept like
any other deletion of an edited event. The delete dialogs count from the data
on the device too (`localTagUsage`, `localCategoryUsage`): offline, those are
exactly the events the deletion takes.

## The outbox

Every write made while the server is out of reach — or while earlier offline
changes still wait, so a new write never overtakes them — goes to the outbox
instead (`Outbox`, persisted as the `outbox` entry of the local store, sealed
on the device like the rest). Each op is the body of the request it stands
for, in wire format: an E2EE account's text is already encrypted.

| Op | Target | Body | Base |
| --- | --- | --- | --- |
| `createEvent` | its temporary id | event fields + `tagsId` | — |
| `updateEvent` | the event id | full state (the PATCH body) | the event as the server had it before the first offline change |
| `deleteEvent` | the event id | — | same |
| `createTag` | its temporary id | `tag` (+ `tagIndex` under E2EE), `idCategory`, `idParentTag` | — |
| `updateTag` | the tag id | full state: `tag` (+ `tagIndex`), `idCategory`, `idParentTag` (null: a main tag) | the tag as the server had it: name, category, main tag |
| `deleteTag` | the tag id | `idParentTag`: the main tag a deleted synonym hands its events to, for the screens | same |
| `createCategory` | its temporary id | `category`, `color`; the op id is its `clientId` | — |
| `updateCategory` | the category id | `category`, `color` | the category as the server had it: name, color, the ids of its tags |
| `deleteCategory` | the category id | `moveTags` | same |
| `createGroup` | its temporary id | `name` (+ `nameIndex`), `idCategory`, `members` | — |
| `updateGroup` | the group id | `name` (+ `nameIndex`), `members` | the group as the server had it: name, members |
| `deleteGroup` | the group id | — | same |

- **Temporary ids** are negative (`-2`, `-3`…), drawn from one counter for
  every kind of thing: something created offline gets one at once, so the
  screens can show and reference it. When its creation is sent, every waiting
  op pointing at it is rewritten with the server id — its target, and the
  bodies using it: an event's `tagsId`, a group's `members`, a synonym's
  `idParentTag`, a tag's or group's `idCategory` — and the mapping is kept for
  a screen still holding the temporary one. A server id only names one thing
  within its kind (event 12 and tag 12 are unrelated): the outbox never
  matches ops of different kinds by id.
- **Folding**: changes to the same thing fold while they wait. Editing
  something created offline rewrites its creation; two edits of the same
  thing make one, keeping the first base; deleting something edited replaces
  the edit. An event created offline and deleted leaves nothing to send; a
  tag, category or group created offline and deleted is created, then
  deleted, so whatever was made with it meanwhile (tags in the category,
  events using the tag) gets the server's own treatment of the deletion. An op
  being sent is never rewritten — a change made meanwhile becomes an op of its
  own.
- **Stamps**: each op records the account's encryption when it was written
  (the E2EE key check, or none) and the server's `dataGeneration`.
- **Strict storage**: unlike the snapshot (a cache), the outbox holds what
  exists nowhere else. A write that cannot be persisted fails instead of being
  lost later.
- **Format**: the persisted outbox carries a version (`v`). An app update that
  changes the shape of an op must upgrade what an older version left waiting —
  never drop it.

The screens show the server data with the outbox applied (`projection.dart`),
the way the server applies each change: creations and edits appear at once
(with a small clock on an event's card), deletions disappear, a main tag moves
with its synonyms, a deleted synonym hands its events to its main tag, a
category deleted with `moveTags` hands its tags and groups to Others, and the
groups follow their members ([tag-groups.md](tag-groups.md), "Lifecycle").
Every event shows its tags as they are now: renamed, moved, or gone. Without
E2EE the server derives the month/year tags of an event; the projection does
the same so a month search finds an event written offline.

## A sync

`SyncEngine` runs when the server answers again (the reachability turns
online), when the app comes back to the foreground, on a pull to refresh, and
right after a write was queued while the server answers. One at a time:

1. **Read the server**: settings, categories, events.
2. **Check the stamps**: an op written for another encryption (enabled,
   disabled or re-keyed on another device meanwhile) or another data
   generation (the server data was restored from a backup, or purged) is
   parked: sending it would write the wrong representation, or hit rows that
   no longer mean the same thing.
3. **Send in order**, one op at a time, each compared with what the server
   has now:

| Op | Server now | Sent |
| --- | --- | --- |
| tag creation | the name exists in the category | nothing: the existing tag is used |
| tag creation | its category was deleted | parked |
| event creation | — | `POST /events` with the op id as `clientId` |
| event creation | a tag it uses was deleted | the creation, without that tag |
| edit | the event exists | a merge of both sides (below) |
| edit | the event was deleted elsewhere | **created again with the edit** |
| deletion | the event is unchanged since the base | `DELETE` |
| deletion | the event was edited elsewhere | **nothing: the event stays** |
| deletion | already gone | nothing |
| category creation | — | `POST /categories` with the op id as `clientId` |
| tag, category or group edit | it exists | a merge of both sides, field by field |
| tag, category or group edit | it was deleted elsewhere | **nothing: the deletion wins**, the change is dropped |
| tag edit | the category or main tag it moves to was deleted elsewhere | parked |
| tag, category or group deletion | unchanged since the base | `DELETE`, never with the events (`deleteEvents: false`) |
| tag, category or group deletion | edited elsewhere (for a category: renamed, recolored, or given a tag this device never showed) | **nothing: it stays** |
| group creation | a group of that name exists in the category | nothing: the existing group is used |
| group creation or edit | its category was deleted, or none of its tags is left | parked |
| a change of something created offline | its creation is parked or was discarded | parked |

4. **Save** the server's state on the device, and tell the screens, which say
   what happened in one message (most important first): changes held back,
   an event restored, a change dropped (deleted elsewhere), something kept,
   a conflict, or simply "sent".

**Merging an edit** — description, period (start, end, ongoing, as one) and
tags (without the date tags) are compared against the base: a field changed
on one side takes that side's value; a field changed on both takes this
device's ("the phone wins"), and the sync says so. Under E2EE the date tags
follow whichever period won (the client owns them there); otherwise the server
derives them again. A tag is merged the same way on its name, its category and
its main tag; a category on its name and its color; a group on its name and its
members (as a whole, like an event's tags), keeping only the members still
there as main tags of the category. Names are compared in clear, so an E2EE
name and its blind index travel together with whichever side won.

After a deletion, or a tag edit that moved or relinked something, the engine
reads the server again before the next op: the server changed more than the
op itself (tags off events, synonyms with their main tag), and what comes next
must be compared with that.

**Conflict policy** (chosen by the maintainer): for events, an edit always
wins over a deletion, in both directions. For tags, categories and groups, a
deletion made here still loses to an edit made elsewhere, but an edit made
here loses to a deletion made elsewhere: the server already took the tag off
its events, so bringing it back would bring it back empty. The same field
changed on both sides keeps this device's value. Nothing is decided silently:
each case shows a message.

**Failures**:

- no answer, a timeout, a gateway error, a `5xx`, `429` or a `401` (the
  session is being renewed): the sync stops, nothing changes, the rest goes
  next time;
- a lost answer (the request reached the server, the reply did not): the op
  is sent again; an event creation carries the same `clientId`, so the server
  answers `200` with the event it already created — never a second one; a tag
  creation answers `409 TAG_NAME_CONFLICT` and the existing tag is used, a
  group creation the same; a category creation carries its `clientId` like an
  event's; an edit (full state) and a deletion (`404` = done) are safe to
  repeat;
- any other refusal (`400`, `403`, `404` on a creation, `422`): the op is
  parked, with every op that needs what it creates (an event using a tag whose
  creation was refused).

**Parked ops** are never sent and never dropped on their own. The app bar
shows a red count; the sheet of waiting changes lists each one with its
reason, and lets the user try again or discard it.

## Reading again

The app reads the server often: at every start, on a pull to refresh, back in
the foreground after a minute, and twice per sync (before sending, and to save
the result). The two big reads, `GET /events` and `GET /categories`, are
conditional ([api.md](api.md), "Conditional reads"): the app saves each body
with the `ETag` the server gave it (`LocalStore`, sealed with the rest) and
sends it back in `If-None-Match`. When nothing changed the server answers
`304` with no body and the saved copy is used (`fetchSaved` in
`homl-ui/lib/data/store/conditional_get.dart`); when anything changed, the
whole body comes, as before.

This is not a delta sync on purpose: the server fingerprints what it would
send, so no write path has to record its changes and none can be forgotten.
The common case — reopening the app with nothing new — costs one request and
no data; a change elsewhere costs one full read. A saved copy without an
`ETag` (an older server, a save that failed) just means a plain read.

## Sessions

- **Logout** with changes waiting asks first: they are lost with the session.
- **A session the server turned down** (password changed elsewhere, PIN
  lockout): the outbox stays sealed on the device; the same account's next
  sign-in sends it. Another account signing in wipes it (the store is tied to
  the account).
- **Enabling or disabling E2EE** is refused while changes wait (they are
  encoded for the current mode); a **purge** drops them along with the data
  they pointed at.

## Limits

- Sync runs while the app is open (foreground). There is no background sync.
- Online-only actions (above) say so instead of waiting.
- The web build shares the code; its outbox lives in the browser storage.
