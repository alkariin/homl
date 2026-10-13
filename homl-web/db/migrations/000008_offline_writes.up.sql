-- Offline writes (docs/api.md, "Replaying a create").
-- clientId: a UUID the client picks for an event it creates, so replaying the
-- POST after a lost answer returns the first row instead of a second one.
-- NULL for every event created without one (several NULLs never collide).
ALTER TABLE `Events`
  ADD COLUMN `clientId` char(36) NULL AFTER `isOngoing`,
  ADD UNIQUE KEY `events_client_unique` (`idUser`, `clientId`);

-- dataGeneration: changes whenever the user's rows are replaced wholesale
-- (E2EE purge, scripts/restore.sh), telling a client whose pending writes
-- were stamped with the old value that the ids they target may now name
-- other rows. The application writes a UUID at registration and purge: an
-- expression default (DEFAULT (UUID())) is refused when the binlog is on,
-- since adding the column would fill the existing rows non-deterministically.
ALTER TABLE `Users`
  ADD COLUMN `dataGeneration` char(36) NOT NULL DEFAULT '';

-- Row-based binlog logs the values, so UUID() is fine in DML.
UPDATE `Users` SET `dataGeneration` = UUID();
