-- Opt-in end-to-end encryption (see docs/e2ee.md).
-- isE2eeEnabled: the per-user mode flag flipped by POST /e2ee/migrate.
-- e2eeKeyCheck: HMAC-SHA256 (lowercase hex) of a fixed string under the
-- client's index key, letting a restoring device verify a typed recovery
-- phrase even when the user has no data yet.
ALTER TABLE `Users`
  ADD COLUMN `isE2eeEnabled` tinyint(1) NOT NULL DEFAULT 0,
  ADD COLUMN `e2eeKeyCheck` varchar(64) DEFAULT NULL;

-- tagIndex: client-side blind index (truncated HMAC, lowercase hex) of the
-- normalized tag name. NULL for non-E2EE users, whose deterministic
-- ciphertext keeps being guarded by the existing UNIQUE(idCategory, tag);
-- for E2EE users the tag column holds non-deterministic blobs (never
-- colliding), so uniqueness and search move to this column.
ALTER TABLE `Tags`
  ADD COLUMN `tagIndex` varchar(32) DEFAULT NULL,
  ADD UNIQUE KEY `tags_index_unique` (`idCategory`, `tagIndex`);
