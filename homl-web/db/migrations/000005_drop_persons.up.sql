-- The person aggregate is gone: a "person" is now an ordinary tag in
-- whatever category the user likes, with synonyms as alternative names
-- (see docs/tag-synonyms.md). Former main tags become plain editable tags.
ALTER TABLE `Tags` DROP FOREIGN KEY `tags_fk2`;
ALTER TABLE `Tags` DROP COLUMN `idPerson`;
DROP TABLE IF EXISTS `Persons`;
