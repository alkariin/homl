ALTER TABLE `Tags`
  ADD COLUMN `idParentTag` int unsigned DEFAULT NULL,
  ADD KEY `tags_fk3` (`idParentTag`),
  ADD CONSTRAINT `tags_fk3` FOREIGN KEY (`idParentTag`) REFERENCES `Tags` (`id`) ON DELETE CASCADE;

-- Existing person nicknames become synonyms of the person's main tag
-- (the lowest tag id of a person was the main tag by convention).
UPDATE Tags t
JOIN (
    SELECT idPerson, MIN(id) AS mainId
    FROM Tags
    WHERE idPerson IS NOT NULL
    GROUP BY idPerson
) m ON t.idPerson = m.idPerson
SET t.idParentTag = m.mainId
WHERE t.id <> m.mainId;
