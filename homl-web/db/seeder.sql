-- Development seed data. Demo credentials: demo@homl.local / Demo1234!
--
-- GENERATED FILE - regenerate with `make seed-gen` after changing
-- ENCRYPT_SECRET (category names are encrypted with the demo user's key).
--
-- All statements use INSERT IGNORE so this file is safe to run multiple times.

INSERT IGNORE INTO Users (id, username, password, language)
VALUES (1, "demo@homl.local", "$2b$08$DkXywmHRdycapf.Nev6K7u7bh/s2SIlrLStC94tfAsvt0sGBukdzK", "en");

INSERT IGNORE INTO Categories (id, category, color, isLocked, kind, idUser)
VALUES (1, "u++LcRq8cwaIBFt4sXPPWGlzC+XfSOToIxaunJ2cVtVL", "#ffff60", 1, 'date', 1); -- Dates

INSERT IGNORE INTO Categories (id, category, color, isLocked, kind, idUser)
VALUES (2, "QNH1VcpIRW1vgbwkt24WwRTIDXsJo09lxzwPDYZWlEMQjTo=", "#60ccff", 1, 'person', 1); -- Persons

INSERT IGNORE INTO Categories (id, category, color, isLocked, kind, idUser)
VALUES (3, "P+B4zIO40YiP/YpAF8+b8M1nBUcJT56URFzfNc4KgmokKQ==", "#999999", 1, 'other', 1); -- Others
