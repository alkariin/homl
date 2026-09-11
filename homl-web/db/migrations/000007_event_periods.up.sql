-- Event periods (see docs/api.md, Events > Periods).
-- endDate: inclusive last day of a closed period; NULL for a single day and
-- for an open period. isOngoing: the period has started and has no end yet,
-- never set together with endDate. Existing rows need no backfill — NULL + 0
-- is exactly the single-day semantics they already had.
-- Both columns stay cleartext in every mode, like date: the server sorts on
-- them and the range filter of phase 2 needs them readable (docs/e2ee.md §1).
ALTER TABLE `Events`
  ADD COLUMN `endDate` date NULL AFTER `date`,
  ADD COLUMN `isOngoing` tinyint(1) NOT NULL DEFAULT 0 AFTER `endDate`;
