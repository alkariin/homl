# Default categories

Every new user gets three categories at registration (seeded from
`src/internal/domain/masterdata/constants.json`, in one transaction with the
user row). Each carries a `kind` (`date`, `person`, `other`; user-created
categories are `custom`) and an `isLocked` flag. This document is the
reference for how each of them behaves in the backend and in the app.

| Category | Kind | Locked | Color | Deletable | Renamable | Tags |
| --- | --- | --- | --- | --- | --- | --- |
| Dates | `date` | yes | `#ffff60` | no | no | backend-managed, read-only |
| Persons | `person` | no | `#60ccff` | yes | yes | user-managed, like any custom category |
| Others | `other` | yes | `#999999` (grey, fixed) | no | no | user-managed; also filled indirectly |

## Dates — mandatory, fully read-only

- The category and its tags are managed by the backend only.
- Tags are the month and year of the user's events: they are created
  automatically when an event is created or updated
  (`eventsService.buildDateTags`), never by the client.
- Enforcement (`application/tag.go`, `application/category.go`):
  - `POST /tags` and `PATCH /tags/:id` reject the date category as target;
  - `PATCH /tags/:id` and `DELETE /tags/:id` reject a tag currently living in
    the date category;
  - `PATCH /categories/:id` and `DELETE /categories/:id` are forbidden on any
    locked category.
- Month names are additionally blacklisted as user tag names
  (`BLACKLIST_TAGS`) so free tags cannot collide with date tags.

## Persons — a default suggestion, not mandatory

- Seeded unlocked: the user may rename it, recolor it, delete it, and manage
  its tags exactly like a custom category. It only exists to suggest a common
  way of organizing tags.
- The `person` kind on the seeded row is purely informative — it marks "the
  Persons category suggested at registration", nothing in the backend keys
  behavior on it. A "person" is just an ordinary tag, with synonyms as
  alternative names (see [tag-synonyms.md](tag-synonyms.md)).
- Migration `000003_unlock_person_category` unlocks the row for accounts
  created before this rule.

## Others — mandatory grey bucket

- Always present and locked: not deletable, not renamable, and its color is
  fixed to grey (`#999999`) — the backend forbids any update of a locked
  category.
- Its **tags** are manageable like any other (rename, synonyms, move,
  delete): this is where the free tags typed on the insert page land, and the
  Categories tab is where the user sorts them into real categories. The
  bucket also fills up indirectly:
  - free tags typed on the insert page are created in it
    (`InsertCubit._defaultCategoryId`), so `POST /tags` keeps accepting it as
    a target;
  - deleting a category with `moveTags: true` moves the orphaned tags into it.
- The app hides the category in the Categories tab while it has no tags
  (`CategoryManagementBody`).

## Custom categories

Everything the user creates is `kind = custom`, unlocked: full CRUD on the
category and its tags (synonyms included, see
[tag-synonyms.md](tag-synonyms.md)), subject only to the tag-name blacklist.
