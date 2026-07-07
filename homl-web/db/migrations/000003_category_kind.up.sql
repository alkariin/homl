-- Add an explicit kind to categories. The three default categories used to be
-- addressed by the fragile convention "first id of the user = date, +1 =
-- person, +2 = other", which breaks under interleaved auto-increments.
ALTER TABLE Categories
  ADD COLUMN `kind` ENUM('date','person','other','custom') NOT NULL DEFAULT 'custom',
  ADD KEY `categories_kind` (`idUser`, `kind`);

-- Backfill existing rows using the id-order convention the data was created
-- with: the locked categories of each user are date, person, other in id order.
UPDATE Categories c
JOIN (
  SELECT idUser, MIN(id) AS minId
  FROM Categories
  WHERE isLocked = 1
  GROUP BY idUser
) m ON c.idUser = m.idUser
SET c.kind = CASE c.id
  WHEN m.minId THEN 'date'
  WHEN m.minId + 1 THEN 'person'
  WHEN m.minId + 2 THEN 'other'
  ELSE 'custom'
END
WHERE c.isLocked = 1;
