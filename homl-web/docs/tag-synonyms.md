# Tag synonyms

A synonym is a tag pointing to another tag of the same category through
`idParentTag` (`NULL` = main tag). Searching or tagging with a synonym is
equivalent to using its main tag: when a synonym is deleted, its event links
are repointed to the parent.

Synonyms started as person "nicknames", limited to the persons category.
That notion is gone: synonyms are a generic tag feature that applies to
**any category except Dates** (date tags are backend-managed, see
[default-categories.md](default-categories.md)). Migration
`000004_nicknames_to_synonyms` detached the legacy nickname tags from their
person so they behave like ordinary synonyms.

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

## Persons

A person is represented in tagging by a single **main tag**
("FirstnameLastname", `Tags.idPerson` set). It is the only tag carrying a
person link:

- it mirrors the person's name and is renamed by `PATCH /persons/:id`;
- it cannot be renamed, moved or deleted through the tag endpoints;
- alternative names ("nicknames") are **plain synonyms** of the main tag,
  created and managed through the tag endpoints like any other synonym.
