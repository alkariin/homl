-- Events had no owner column: every ownership check had to go through
-- EventsTags, and the update/delete paths did not check at all. Add the owner
-- directly on the event so it can be enforced on every statement.
ALTER TABLE Events ADD COLUMN `idUser` int unsigned NULL;

UPDATE Events e
JOIN (SELECT DISTINCT idEvent, idUser FROM EventsTags) et ON e.id = et.idEvent
SET e.idUser = et.idUser;

-- Events without any EventsTags row are unreachable by every user (reads go
-- through EventsTags): drop them instead of keeping unowned rows.
DELETE FROM Events WHERE idUser IS NULL;

ALTER TABLE Events
  MODIFY COLUMN `idUser` int unsigned NOT NULL,
  ADD KEY `events_fk_user` (`idUser`),
  ADD CONSTRAINT `events_fk_user` FOREIGN KEY (`idUser`) REFERENCES `Users` (`id`) ON DELETE CASCADE;
