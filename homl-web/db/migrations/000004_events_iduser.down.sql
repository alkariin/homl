ALTER TABLE Events
  DROP FOREIGN KEY `events_fk_user`,
  DROP KEY `events_fk_user`,
  DROP COLUMN `idUser`;
