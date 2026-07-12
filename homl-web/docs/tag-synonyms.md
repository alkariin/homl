# Tag synonyms

A synonym is a tag pointing to another tag of the same category through
`idParentTag` (`NULL` = main tag). Searching or tagging with a synonym is
equivalent to using its main tag: when a synonym is deleted, its event links
are repointed to the parent.

Synonyms started as person "nicknames", limited to the persons category.
That notion is gone — and with it the whole person aggregate: a "person" is
now an ordinary tag (e.g. "JaneDoe") in whatever category the user likes,
with synonyms as alternative names. Synonyms are a generic tag feature that
applies to **any category except Dates** (date tags are backend-managed, see
[default-categories.md](default-categories.md)). Migrations
`000004_nicknames_to_synonyms` and `000005_drop_persons` converted the
legacy nickname tags into ordinary synonyms and dropped the `Persons` table
and the `Tags.idPerson` link (former person main tags become plain editable
tags).

## Rules

Enforced in `application/tag.go` (`validateTag` / `validateParent`):

- A synonym lives in the **same category** as its parent.
- Depth is **one level**: a synonym cannot be a parent, and a tag that has
  synonyms cannot become one.
- A tag cannot be its own synonym.
- Synonym names go through the same checks as any tag (title-cased,
  blacklist).
- The date category is off-limits (no tag creation at all, synonym or not).

## Lifecycle

Handled in `persistence/tag.go` (`DeleteTag`):

- Deleting a **synonym** repoints its `EventsTags` rows to the parent
  (dropping duplicates when the event already carries the parent).
- Deleting a **main tag** promotes its oldest synonym as the new main tag
  before the delete.
- Deleting a category cascades to its tags; with `moveTags: true` the tags
  (synonym links included) move to the Others category instead.
