# Data export and import

How a user takes a copy of their data out of HOML, and brings it back — into
the same account, a new one, or an account on another server. Both live on
the Security page of the app (**Export my data**, **Import data**) and run
entirely on the device (`homl-ui/lib/data/transfer/`,
`homl-ui/lib/data/repositories/data_transfer.repository.dart`): there is no
export endpoint. The server never sees the file, and under E2EE only the
device can read the data anyway.

Related: [api.md](api.md) (the routes the import writes through),
[e2ee.md](e2ee.md), [offline-sync.md](offline-sync.md),
[default-categories.md](default-categories.md),
[tag-synonyms.md](tag-synonyms.md), [tag-groups.md](tag-groups.md),
[event-periods.md](event-periods.md).

## What the file holds

| In the file | Not in the file |
| --- | --- |
| the categories: name, color, kind | the Dates category and every date tag (month, year, `Ongoing`): they follow from the periods and are rebuilt on import |
| the tags, each main tag with its synonyms | server ids: everything is referenced by name |
| the tag groups, each with the names of its tags | a group whose tags were all deleted |
| the events: start day, end day or "ongoing", description, tags | settings (language, home tab), PIN, fingerprint, password |
| when it was exported | the E2EE key or recovery phrase |

## Plain file (`homl-export`, version 1)

UTF-8 JSON, indented so it stays readable. Written by `ExportFile.toJson`,
read back (and checked) by `ExportFile.fromJson`.

```json
{
  "format": "homl-export",
  "version": 1,
  "exportedAt": "2026-10-17T10:00:00.000Z",
  "categories": [
    {
      "name": "Persons",
      "kind": "person",
      "color": "#60ccff",
      "tags": [
        { "name": "Alice", "synonyms": ["Ali"] },
        { "name": "Bob" }
      ],
      "groups": [
        { "name": "Family", "tags": ["Alice", "Bob"] }
      ]
    },
    {
      "name": "Others",
      "kind": "other",
      "color": "#999999",
      "tags": [ { "name": "Football" } ]
    }
  ],
  "events": [
    {
      "date": "2026-07-05",
      "endDate": "2026-07-09",
      "description": "Holidays",
      "tags": [
        { "category": "Persons", "tag": "Ali" },
        { "category": "Others", "tag": "Football" }
      ]
    },
    {
      "date": "2026-09-01",
      "isOngoing": true,
      "tags": [ { "category": "Persons", "tag": "Bob" } ]
    }
  ]
}
```

| Field | Rules |
| --- | --- |
| `format`, `version` | `homl-export` and `1`. A higher version is refused with "update the app", anything else as not an export |
| `exportedAt` | ISO 8601 instant, shown before an import |
| `categories[].name` | non-blank; names are matched without case or surrounding spaces |
| `categories[].kind` | optional: `person`, `other`, `custom` (see [default-categories.md](default-categories.md)); a `date` category is ignored on import |
| `categories[].color` | a hex color the backend accepts (`#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`) |
| `categories[].tags[]` | `name` (non-blank) and optional `synonyms` (non-blank names) |
| `categories[].groups[]` | optional: `name` (non-blank) and `tags`, at least one name, each listed under the category's `tags` (a synonym stands for its main tag) |
| `events[].date` | `YYYY-MM-DD`, a calendar day like the backend `DATE` column |
| `events[].endDate` | optional, inclusive end of a closed period, not before `date`; one on `date` is read as a single day |
| `events[].isOngoing` | optional, `true` for an open period; never with `endDate` |
| `events[].description` | optional, plain text |
| `events[].tags[]` | `{category, tag}`: the tag (main or synonym) of that name in the category of that name, which **must** be listed under `categories` |

The groups came with version 1 as an optional field, so the version did not
change: an app that predates them reads such a file and imports everything
but the groups.

Events are written oldest first, the events of one day in the order they were
created; an import creates them in file order, so the day's order survives
the round trip. Optional fields are left out when empty.

The whole file is checked before the first write: a file that breaks any rule
above is refused as a whole ("not a HOML export, or damaged"), never imported
halfway.

## Password-protected file (`homl-export-encrypted`, version 1)

The export dialog offers to protect the file with a password (at least 8
characters). The plain file above is then encrypted as a whole and wrapped in
a JSON envelope that names its parameters (`ExportSeal`):

```json
{
  "format": "homl-export-encrypted",
  "version": 1,
  "kdf": { "algorithm": "PBKDF2-HMAC-SHA256", "iterations": 600000, "salt": "<base64, 16 bytes>" },
  "cipher": "AES-256-GCM",
  "nonce": "<base64, 12 bytes>",
  "ciphertext": "<base64: ciphertext followed by the 16-byte GCM tag>"
}
```

- The key is PBKDF2-HMAC-SHA256 over the password as typed, with a fresh
  random salt per file — 600 000 rounds by default (OWASP's figure), native on
  Android and WebCrypto on the web. A file asking for more than 10 million
  rounds is refused, so a crafted one cannot freeze the app.
- AES-256-GCM with a fresh random nonce; the tag also catches an altered file.
  A wrong password and an altered file are therefore the same error ("wrong
  password").
- Nothing ties the file to the account, the device or the server: the
  password alone opens it, anywhere. It is unrelated to the E2EE key, which
  never leaves the device, and it cannot be recovered.
- The file name says which kind it is: `homl-export-2026-10-17.json`, or
  `homl-export-2026-10-17-encrypted.json`.

## Export

- Reads what the app shows, through the repositories: the server copy when it
  answers, else the copy saved on the device — an export works offline, the
  changes waiting to be sent included.
- **E2EE accounts**: the repositories decrypt at their boundary, so the file
  holds the data in clear. The password switch is therefore on by default for
  them, and turning it off shows a warning. A plain account starts with the
  switch off.
- Saving goes through the platform save dialog (`file_picker`): the Android
  document picker, a download on the web.

## Import

The file's content is **added** to the account; what the account already
holds is matched and skipped, and nothing existing is ever changed or
deleted. That makes an import idempotent: importing the same file twice
changes nothing the second time.

1. **Picking and reading.** Any file can be picked; a protected one asks for
   its password (asked again after a wrong one). The confirmation dialog then
   shows the export date and the counts of events, tags, tag groups and
   categories.
2. **Preconditions.** The import compares the file with what the *server*
   holds, so it needs the server, and no offline change waiting in the outbox
   (it would refuse with "send or discard them first"). It reads the
   categories and events from the server itself, never from the device copy.
3. **Categories.** A category of the file is the account's category of the
   same name (case aside); a missing one is created with the file's color.
   The `other` category goes to the account's Others whatever its name (the
   seeded one is called `Others` everywhere, but the rule does not depend on
   it). The `person` kind is informative only: a Persons category renamed in
   the file is matched by its name like any other. A file that gives no kind
   (one written by hand) is read by the names: a category named like the
   account's Dates is ignored, one named like its Others goes there. Two
   categories of the file with the same name are one category on import.
4. **Tags.** A tag is the tag of the same name in that category; a missing one
   is created, a synonym under its main tag (under the main tag's own parent
   when the account's tag of that name is itself a synonym — synonyms stay one
   level deep). An existing tag keeps its place: an import never turns a main
   tag into a synonym or moves a tag.
5. **Tag groups.** A group is the group of the same name in that category,
   left as it is; a missing one is created with the category's tags of its
   names, a synonym standing for its main tag. A tag refused on the way is
   left out of it, and a group left with no tag at all is skipped.
6. **Events.** An event is skipped when the account already has one with the
   same start, end, "ongoing" flag, description and non-date tags; each
   account event covers one copy, so two identical events in the file need
   two in the account. The others are created, with their date tags derived as
   usual.
7. **Refusals.** What the server (or, under E2EE, the client-side mirror of
   its rules) refuses — a reserved tag name such as a four-digit `1984`, for
   instance — is left out and counted, and the import goes on: a refused tag
   is dropped from the events that carried it, and a refused category takes
   its tags and groups with it.
8. **Report.** Added events, tags, tag groups and categories, the events that
   were already there, and the items left out.

**Connection lost.** Each write goes through the regular repositories; one
that cannot reach the server stops the import at once ("connection lost") —
at most that one write waits in the outbox, sent later like any offline
change. What reached the server stays. Importing the same file again finishes
the job, the matching above skipping what is already there.

**One reload.** The writes do not notify the app one by one: the home screen
reloads once, at the end (`EventsRepository.createEvent(notify: false)` then
`notifyChanged`).

**E2EE accounts.** The writes go through the same repositories as the forms,
so names and descriptions are encrypted with the blind index sent alongside,
the tag blacklist is enforced client-side, and the date tags are created and
attached by the client (`periodDateTagNames`), as the insert form does.

**Names.** A plain account stores category and tag names title-cased (the
backend normalization), an E2EE account as typed. Matching ignores case, so
this changes nothing to the merge — only how a re-exported name is spelled.

## Limits

- No "replace everything" mode: an import only adds. Start from a fresh
  account (or delete the unwanted data first) for an exact restore.
- Not one transaction: a big import is many requests. It is resumable rather
  than atomic — run it again after an interruption.
- Requests are sent one at a time, to keep the creation order; a few thousand
  events take a minute or two on a home server.
- The file is kept in memory while it is read: fine for a journal (a few
  megabytes at most).
