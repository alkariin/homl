# Offline writes and sync

How the Flutter client (`homl-ui/lib/data/sync/`) lets a user write while the
server is out of reach — a phone away from the home network cannot see a NAS
on the LAN — and sends everything once it answers again. The server stays the
judge of every write: the client only replays the regular REST calls, so the
Go rules (period validation, tag uniqueness, synonyms, date tags) apply to
offline writes exactly as to online ones.

Related: [auth-flows.md](auth-flows.md) ("Client session": how the session
survives without the server), [api.md](api.md) (the `clientId` of
`POST /events`, `dataGeneration` in the settings), [e2ee.md](e2ee.md) §6.

## What works offline

| Offline | Online only (a clear "server unreachable") |
| --- | --- |
| browsing and searching the data saved on the device | renaming, moving or deleting a tag |
| creating, editing and deleting events | creating, editing or deleting a category |
| creating tags (typed in the form, or a new tag in a category) | settings, PIN, fingerprint, password, account |
| | enabling / disabling end-to-end encryption |

A tag created offline cannot be renamed, moved or deleted before the server has
it (`TagPendingFailure`): only its creation waits.

## The outbox

Every write made while the server is out of reach — or while earlier offline
changes still wait, so a new write never overtakes them — goes to the outbox
instead (`Outbox`, persisted as the `outbox` entry of the local store, sealed
on the device like the rest). Each op is the body of the request it stands
for, in wire format: an E2EE account's text is already encrypted.

| Op | Target | Body | Base |
| --- | --- | --- | --- |
| `createTag` | its temporary id | `tag` (+ `tagIndex` under E2EE), `idCategory`, `idParentTag` | — |
| `createEvent` | its temporary id | event fields + `tagsId` | — |
| `updateEvent` | the event id | full state (the PATCH body) | the event as the server had it before the first offline change |
| `deleteEvent` | the event id | — | same |

- **Temporary ids** are negative (`-2`, `-3`…): an event or tag created
  offline gets one at once, so the screens can show and reference it. When its
  creation is sent, every waiting op pointing at it is rewritten with the
  server id, and the mapping is kept for a screen still holding the temporary
  one.
- **Folding**: changes to the same thing fold while they wait. Editing an
  event created offline rewrites its creation; deleting it drops it (nothing
  is ever sent); two edits of a server event make one, keeping the first
  base; deleting an edited event replaces the edit. An op being sent is never
  rewritten — a change made meanwhile becomes an op of its own.
- **Stamps**: each op records the account's encryption when it was written
  (the E2EE key check, or none) and the server's `dataGeneration`.
- **Strict storage**: unlike the snapshot (a cache), the outbox holds what
  exists nowhere else. A write that cannot be persisted fails instead of being
  lost later.
- **Format**: the persisted outbox carries a version (`v`). An app update that
  changes the shape of an op must upgrade what an older version left waiting —
  never drop it.

The screens show the server data with the outbox applied (`projection.dart`):
creations and edits appear at once (with a small clock on the card), deletions
disappear, tags created offline are in their category. Without E2EE the server
derives the month/year tags of an event; the projection does the same so a
month search finds an event written offline.

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

4. **Save** the server's state on the device, and tell the screens, which say
   what happened in one message (most important first): changes held back,
   an event restored, an event kept, a conflict, or simply "sent".

**Merging an edit** — description, period (start, end, ongoing, as one) and
tags (without the date tags) are compared against the base: a field changed
on one side takes that side's value; a field changed on both takes this
device's ("the phone wins"), and the sync says so. Under E2EE the date tags
follow whichever period won (the client owns them there); otherwise the server
derives them again.

**Conflict policy** (chosen by the maintainer): an edit always wins over a
deletion, in both directions; the same field changed on both sides keeps this
device's value. Nothing is decided silently: each case shows a message.

**Failures**:

- no answer, a timeout, a gateway error, a `5xx`, `429` or a `401` (the
  session is being renewed): the sync stops, nothing changes, the rest goes
  next time;
- a lost answer (the request reached the server, the reply did not): the op
  is sent again; an event creation carries the same `clientId`, so the server
  answers `200` with the event it already created — never a second one; a tag
  creation answers `409 TAG_NAME_CONFLICT` and the existing tag is used; an
  edit (full state) and a deletion (`404` = done) are safe to repeat;
- any other refusal (`400`, `403`, `404` on a creation, `422`): the op is
  parked, with every op that needs what it creates (an event using a tag whose
  creation was refused).

**Parked ops** are never sent and never dropped on their own. The app bar
shows a red count; the sheet of waiting changes lists each one with its
reason, and lets the user try again or discard it.

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
