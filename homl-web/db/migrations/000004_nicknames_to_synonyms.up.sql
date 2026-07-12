-- Nicknames disappear as a concept: a person's alternative names are plain
-- tag synonyms of the main tag, manageable through the tag endpoints like
-- any other synonym (see docs/tag-synonyms.md). Only the main tag keeps its
-- person link.
UPDATE Tags SET idPerson = NULL WHERE idPerson IS NOT NULL AND idParentTag IS NOT NULL;
