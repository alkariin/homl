-- Development seed data. Demo credentials: demo@homl.local / Demo1234!
--
-- Category values are encrypted with ENCRYPT_SECRET=change_me_encrypt_secret (default).
-- If you use a custom ENCRYPT_SECRET, re-generate the encrypted values with make seed-gen.
--
-- All statements use INSERT IGNORE so this file is safe to run multiple times.

INSERT IGNORE INTO Users (id, username, password, language)
VALUES (1, "demo@homl.local", "$2b$08$DkXywmHRdycapf.Nev6K7u7bh/s2SIlrLStC94tfAsvt0sGBukdzK", "en");

INSERT IGNORE INTO Categories (id, category, color, isLocked, kind, idUser)
VALUES (1, "7k/SRG8=", "#ffff60", 1, 'date', 1); -- Dates

INSERT IGNORE INTO Categories (id, category, color, isLocked, kind, idUser)
VALUES (2, "+kvUUnPivA==", "#60ccff", 1, 'person', 1); -- Persons

INSERT IGNORE INTO Categories (id, category, color, isLocked, kind, idUser)
VALUES (3, "5VrORG7/", "#999999", 1, 'other', 1); -- Others
