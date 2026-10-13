ALTER TABLE `Users`
  DROP COLUMN `dataGeneration`;

ALTER TABLE `Events`
  DROP INDEX `events_client_unique`,
  DROP COLUMN `clientId`;
