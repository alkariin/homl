-- Re-attach the person link to the synonyms of a person's main tag.
UPDATE Tags t
JOIN Tags p ON t.idParentTag = p.id
SET t.idPerson = p.idPerson
WHERE t.idPerson IS NULL AND p.idPerson IS NOT NULL;
