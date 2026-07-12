-- Restores the schema only: the person rows and tag links are gone for good.
CREATE TABLE IF NOT EXISTS `Persons` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `firstname` varchar(255) NOT NULL,
  `lastname` varchar(255) NOT NULL,
  `idCategory` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `persons_fk` (`idCategory`),
  CONSTRAINT `persons_fk` FOREIGN KEY (`idCategory`) REFERENCES `Categories` (`id`)
);
ALTER TABLE `Tags`
  ADD COLUMN `idPerson` int unsigned DEFAULT NULL,
  ADD KEY `tags_fk2` (`idPerson`),
  ADD CONSTRAINT `tags_fk2` FOREIGN KEY (`idPerson`) REFERENCES `Persons` (`id`) ON DELETE CASCADE;
