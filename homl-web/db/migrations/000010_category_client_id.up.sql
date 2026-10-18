-- Offline category creation (docs/offline-sync.md). Category names are not
-- unique, so a POST replayed after a lost answer cannot be recognised by its
-- name like a tag or a tag group: it carries the clientId the app picked,
-- and the replay returns the first row instead of a second one. NULL for
-- every category created without one (several NULLs never collide).
ALTER TABLE `Categories`
  ADD COLUMN `clientId` char(36) NULL AFTER `kind`,
  ADD UNIQUE KEY `categories_client_unique` (`idUser`, `clientId`);
