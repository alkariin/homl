-- Tag groups (docs/tag-groups.md): a named set of main tags of one category,
-- which the client expands into its members when the user picks it. A group
-- is never linked to an event.
-- name: at-rest ciphertext (deterministic, so the plain unique key guards the
-- names of non-E2EE users) or an E2EE client blob.
-- nameIndex: client-side blind index of the normalized name, the same HMAC as
-- Tags.tagIndex. NULL for non-E2EE users; E2EE blobs never collide, so the
-- uniqueness of their names moves to this column.
CREATE TABLE IF NOT EXISTS `TagGroups` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `nameIndex` varchar(32) DEFAULT NULL,
  `idCategory` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `tagGroups_name_unique` (`idCategory`, `name`),
  UNIQUE KEY `tagGroups_index_unique` (`idCategory`, `nameIndex`),
  CONSTRAINT `tagGroups_fk` FOREIGN KEY (`idCategory`) REFERENCES `Categories` (`id`) ON DELETE CASCADE
);

-- Deleting a group or one of its tags removes the membership.
CREATE TABLE IF NOT EXISTS `TagGroupMembers` (
  `idGroup` int unsigned NOT NULL,
  `idTag` int unsigned NOT NULL,
  PRIMARY KEY (`idGroup`, `idTag`),
  KEY `tagGroupMembers_fk2` (`idTag`),
  CONSTRAINT `tagGroupMembers_fk` FOREIGN KEY (`idGroup`) REFERENCES `TagGroups` (`id`) ON DELETE CASCADE,
  CONSTRAINT `tagGroupMembers_fk2` FOREIGN KEY (`idTag`) REFERENCES `Tags` (`id`) ON DELETE CASCADE
);
