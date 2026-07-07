ALTER TABLE `Tags`
  DROP FOREIGN KEY `tags_fk3`,
  DROP KEY `tags_fk3`,
  DROP COLUMN `idParentTag`;
