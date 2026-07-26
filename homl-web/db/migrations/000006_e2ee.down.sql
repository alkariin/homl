ALTER TABLE `Tags`
  DROP KEY `tags_index_unique`,
  DROP COLUMN `tagIndex`;

ALTER TABLE `Users`
  DROP COLUMN `e2eeKeyCheck`,
  DROP COLUMN `isE2eeEnabled`;
