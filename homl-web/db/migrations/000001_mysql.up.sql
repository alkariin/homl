/*!40101 SET NAMES utf8 */;
/*!40014 SET FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET SQL_NOTES=0 */;
CREATE TABLE IF NOT EXISTS `Categories` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `category` varchar(255) NOT NULL,
  `color` varchar(255) NOT NULL,
  `isLocked` tinyint(1) NOT NULL,
  `idUser` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `categories_fk` (`idUser`),
  CONSTRAINT `categories_fk` FOREIGN KEY (`idUser`) REFERENCES `Users` (`id`) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS `Events` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `description` text NULL,
  `date` date NOT NULL,
  PRIMARY KEY (`id`)
);
CREATE TABLE IF NOT EXISTS `EventsTags` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `idTag` int unsigned NOT NULL,
  `idEvent` int unsigned NOT NULL,
  `idUser` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `eventsTags_fk` (`idTag`),
  KEY `eventsTags_fk2` (`idEvent`),
  KEY `eventsTags_fk3` (`idUser`),
  CONSTRAINT `eventsTags_fk` FOREIGN KEY (`idTag`) REFERENCES `Tags` (`id`) ON DELETE CASCADE,
  CONSTRAINT `eventsTags_fk2` FOREIGN KEY (`idEvent`) REFERENCES `Events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `eventsTags_fk3` FOREIGN KEY (`idUser`) REFERENCES `Users` (`id`) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS `Persons` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `firstname` varchar(255) NOT NULL,
  `lastname` varchar(255) NOT NULL,
  `idCategory` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `persons_fk` (`idCategory`),
  CONSTRAINT `persons_fk` FOREIGN KEY (`idCategory`) REFERENCES `Categories` (`id`)
);
CREATE TABLE IF NOT EXISTS `Tags` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tag` varchar(255) NOT NULL,
  `idCategory` int unsigned NOT NULL,
  `idPerson` int unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `tag` (`idCategory`, `tag`),
  KEY `tags_fk` (`idCategory`),
  KEY `tags_fk2` (`idPerson`),
  CONSTRAINT `tags_fk` FOREIGN KEY (`idCategory`) REFERENCES `Categories` (`id`) ON DELETE CASCADE,
  CONSTRAINT `tags_fk2` FOREIGN KEY (`idPerson`) REFERENCES `Persons` (`id`) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS `Users` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `language` varchar(255) NOT NULL,
  `defaultScreen` tinyint(1) DEFAULT 0,
  `isFingerprintEnabled` tinyint(1) DEFAULT 0,
  `pkey` varchar(255),
  `challenge` varchar(255),
  `pin` varchar(255),
  `isPinEnabled` tinyint(1) DEFAULT 0,
  `pinTryCounter` int unsigned,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`)
);