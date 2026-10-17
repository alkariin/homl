# Tag groups

A tag group is a named set of main tags of one category: "Family" in the
Persons category, holding "Alice" and "Bob". It is a shortcut for typing,
not a tag. When the user picks the group, the app adds its members. The group
itself is never linked to an event, so:

- an event says exactly which tags it has: if Bob was not there, the user
  removes that chip and the event only gets Alice;
- changing a group later (adding "Carol") never changes the events tagged
  before;
- searching, synonyms and date tags work as before, because events only
  carry real tags.

Groups belong to the Category aggregate, like tags and synonyms
([tag-synonyms.md](tag-synonyms.md)). They are stored in `TagGroups` (name and
category) and `TagGroupMembers` (one row per member), both added by migration
`000009_tag_groups`.

## Rules

Enforced in `application/tag_group.go` and by the schema:

- A group lives in **one category** and never changes category on its own
  (`PATCH` ignores `idCategory`). Moving the tags in bulk (a category deletion
  with `moveTags`) takes it along, see below.
- Its members are **main tags of that category**: no synonym, no tag of
  another category, no other user's tag (`CheckMainTagsInCategory`). The
  list is deduplicated, and a write needs at least one member.
- The **Dates** category holds no group, for E2EE users too: date tags come
  from the event periods, never from the user's typing.
- The name follows the tag name rules: title-cased (non-E2EE), and the
  reserved date names are refused (the month names, `Ongoing` and any
  four-digit name). The user types group and tag names in the same field.
- Group names are **unique per category** (the unique keys on
  `(idCategory, name)` and `(idCategory, nameIndex)`), refused with `409`
  `TAG_NAME_CONFLICT` like a tag name. The server does not stop a group from
  sharing its name with a tag, or with a group of another category.

## Lifecycle

The groups follow their tags, in the same transaction as the tag write:

| Change | Effect on the groups |
| --- | --- |
| A member is deleted | it leaves the group (`TagGroupMembers` cascade); a group can end up empty and stays |
| A member is renamed | nothing: members are ids |
| A member moves to another category (`PATCH /tags/:id`) | it leaves the groups of its old category |
| A member becomes a synonym | its main tag takes its place in the groups of the main tag's category (no duplicate when the main tag is already a member) |
| A main tag moves with its synonyms | nothing for the synonyms: they are never members |
| The category is deleted with `moveTags: true` | its groups move to Others with their members; a group name already taken there refuses the whole deletion with `409` `TAG_NAME_CONFLICT` |
| The category is deleted without `moveTags` | its groups are deleted with its tags |
| A group is deleted | only the shortcut goes: the tags and their events stay |

`UpdateTag` handles the member move and the synonym hand-over
(`persistence/tag.go`); the category deletion moves or cascades the groups
(`persistence/category.go`).

## E2EE

For an E2EE user the name is an `e2ee:v1:` blob and `nameIndex` carries its
blind index — the same HMAC as `Tags.tagIndex`, over the normalized name. The
server checks their shape only; normalization and the reserved names are the
client's job, like for tags. Members are plain ids, visible to the server like
the event-tag links. `POST /e2ee/migrate` carries the group names in
`tagGroups`, and the purge deletes them with the categories. See
[e2ee.md](e2ee.md).

## In the app

Details and file pointers: the homl-ui README, "Tag groups".

- **Picking a group.** Both tag inputs suggest the groups with the tags.
  Picking one (a tap, or its name typed in full then enter) adds its tags
  that are not there yet; a group with nothing left to add is not offered.
  On the Insert tab the event gets the tags. On the Search tab each tag
  becomes a filter, and the search keeps its AND semantics: "Family" finds
  the events carrying all of its tags. The picker sheet lists the groups too.
- **A name shared with a tag.** Enter adds the tag, what was typed; the group
  stays a tap away in the dropdown.
- **Managing groups.** In the Categories tab, under the tags of a category:
  "New group", then a tap on a group to edit or delete it. The dialog refuses
  a name reserved for the dates, and any name a tag or another group of the
  account already has, whatever its category, so a typed name never means
  two things. Online only, like every category change; a tag created
  offline joins a group once it reached the server.
- **Export and import.** A group travels in the export file with the names
  of its tags ([data-export.md](data-export.md)).

## API

See [api.md](api.md#tag-groups): `POST /tagGroups`, `PATCH /tagGroups/:id`,
`DELETE /tagGroups/:id`, and the `groups` of each category in
`GET /categories`.
