// Command seedgen regenerates db/seeder.sql: it encrypts the demo user's
// default categories with the configured ENCRYPT_SECRET (keys are derived per
// user, so the values are bound to the demo user's id). Run it whenever the
// secret or the encryption scheme changes:
//
//	make seed-gen
package main

import (
	"fmt"
	"log"
	"os"

	"github.com/alkariin/homl/homl-web/internal/domain/masterdata"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/crypto"
)

// The emitted category inserts are guarded on the kind, which assumes the
// default set holds at most one category per kind (date, person, other).
//
// demoUserID must match the id in the Users insert below.
const demoUserID = 1

// demoPasswordHash is the bcrypt hash of "Demo1234!".
const demoPasswordHash = "$2b$08$DkXywmHRdycapf.Nev6K7u7bh/s2SIlrLStC94tfAsvt0sGBukdzK"

func main() {
	secret := os.Getenv("ENCRYPT_SECRET")
	if secret == "" {
		log.Fatal("ENCRYPT_SECRET is not set; run through `make seed-gen` so .env is loaded")
	}

	keyring := crypto.NewKeyring(secret)

	fmt.Println("-- Development seed data. Demo credentials: demo@homl.local / Demo1234!")
	fmt.Println("--")
	fmt.Println("-- GENERATED FILE - regenerate with `make seed-gen` after changing")
	fmt.Println("-- ENCRYPT_SECRET (category names are encrypted with the demo user's key).")
	fmt.Println("--")
	fmt.Println("-- Every statement is guarded so this file is safe to run multiple times.")
	fmt.Println()
	fmt.Printf("INSERT IGNORE INTO Users (id, username, password, language)\nVALUES (%d, \"demo@homl.local\", \"%s\", \"en\");\n", demoUserID, demoPasswordHash)

	fmt.Println()
	fmt.Println("-- The categories carry no explicit id and are guarded on their kind: the")
	fmt.Println("-- app deletes and recreates the whole default set (E2EE purge), which frees")
	fmt.Println("-- the ids a plain INSERT IGNORE relied on and would re-seed a second,")
	fmt.Println("-- empty \"Dates\"/\"Persons\"/\"Others\" set next to the live one.")
	for _, cat := range masterdata.DefaultCategories() {
		enc, err := keyring.Encrypt(cat.Name, demoUserID)
		if err != nil {
			log.Fatalf("could not encrypt %q: %v", cat.Name, err)
		}
		locked := 0
		if cat.Locked {
			locked = 1
		}
		fmt.Println()
		fmt.Printf("INSERT INTO Categories (category, color, isLocked, kind, idUser)\nSELECT \"%s\", \"%s\", %d, '%s', %d FROM DUAL\nWHERE NOT EXISTS (SELECT 1 FROM Categories WHERE idUser = %d AND kind = '%s'); -- %s\n", enc, cat.Color, locked, cat.Kind, demoUserID, demoUserID, cat.Kind, cat.Name)
	}
}
