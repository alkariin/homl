-- The person category is no longer mandatory: it becomes a default
-- suggestion the user may rename or delete (see docs/default-categories.md).
UPDATE Categories SET isLocked = 0 WHERE kind = 'person';
