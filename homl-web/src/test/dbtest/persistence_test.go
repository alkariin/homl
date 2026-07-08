//go:build dbtest

// Package dbtest contains DB-backed integration tests for the persistence
// layer, focused on cross-tenant isolation: the very authorization gaps that
// unit tests (which mock the repositories) cannot catch.
//
// They are gated behind the `dbtest` build tag so they never run as part of
// the normal `go test ./...`. They need a migrated MySQL (make db-up +
// migrateup provide one):
//
//	cd homl-web && make db-up && make migrateup
//	make test-db     # or: go test -tags dbtest ./test/dbtest/...
//
// Configure the target via DBTEST_DSN (default matches make db-up).
package dbtest

import (
	"context"
	"os"
	"testing"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/jmoiron/sqlx"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
	"github.com/alkariin/homl/homl-web/internal/domain/person"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/crypto"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/persistence"
)

func dsn() string {
	if v := os.Getenv("DBTEST_DSN"); v != "" {
		return v
	}
	return "homl:change_me_mysql@tcp(localhost:3306)/homl?parseTime=true"
}

type repos struct {
	db     *sqlx.DB
	aes    *crypto.Keyring
	users  user.Repository
	cats   category.Repository
	events event.Repository
	person person.Repository
}

func setup(t *testing.T) *repos {
	t.Helper()
	db, err := sqlx.Connect("mysql", dsn())
	require.NoError(t, err, "connect to test MySQL (run: make db-up && make migrateup)")
	t.Cleanup(func() { db.Close() })

	aes := crypto.NewKeyring("dbtest-secret-dbtest-secret-0123")
	return &repos{
		db:     db,
		aes:    aes,
		users:  persistence.NewUsersRepository(db, nil, aes),
		cats:   persistence.NewCategoriesRepository(db, aes),
		events: persistence.NewEventsRepository(db, aes),
		person: persistence.NewPersonsRepository(db, aes),
	}
}

func (r *repos) enc(t *testing.T, text string, idUser uint64) string {
	t.Helper()
	v, err := r.aes.Encrypt(text, idUser)
	require.NoError(t, err)
	return v
}

// newUser registers a fresh user with a unique username and returns its id.
// Everything it creates is removed at the end of the test via ON DELETE
// CASCADE from the Users row.
func newUser(t *testing.T, r *repos) uint64 {
	t.Helper()
	ctx := context.Background()
	lang := user.Language("en")
	// A unique username per call keeps the test independent of existing data.
	name := "dbtest-" + time.Now().Format("150405.000000000") + "@homl.local"
	u := &user.User{Username: name, Password: "hash"}
	require.NoError(t, r.users.Registration(ctx, u, &lang))
	require.NotZero(t, u.ID)
	t.Cleanup(func() {
		r.db.Exec("DELETE FROM Users WHERE id = ?", u.ID)
	})
	return u.ID
}

func TestCrossTenantEventIsolation(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	alice := newUser(t, r)
	mallory := newUser(t, r)

	// Alice creates an event with one tag (events are only reachable through
	// their EventsTags rows, so a tag-less event would be invisible).
	aliceOther, err := r.cats.FindIdByKind(ctx, alice, category.KindOther)
	require.NoError(t, err)
	aliceTag, err := r.cats.CreateTag(ctx, r.enc(t, "Trip", alice), aliceOther, nil)
	require.NoError(t, err)
	require.NoError(t, r.events.CreateEventWithTags(ctx, nil, []uint{aliceTag}, &event.Event{Description: r.enc(t, "secret", alice), Date: time.Now()}, alice))
	aliceEvents, _, err := r.events.FindEventsWithTags(ctx, nil, alice)
	require.NoError(t, err)
	require.Len(t, aliceEvents, 1)
	var eventID uint
	for id := range aliceEvents {
		eventID = id
	}

	t.Run("mallory cannot delete alice's event", func(t *testing.T) {
		err := r.events.Delete(ctx, eventID, mallory)
		assert.Error(t, err)

		got, _, err := r.events.FindEventsWithTags(ctx, nil, alice)
		require.NoError(t, err)
		assert.Len(t, got, 1, "alice's event must survive")
	})

	t.Run("mallory cannot update alice's event", func(t *testing.T) {
		err := r.events.UpdateEventWithTags(ctx, nil, nil, &event.Event{Id: eventID, Description: "hacked", Date: time.Now()}, mallory)
		assert.Error(t, err)
	})

	t.Run("mallory cannot see alice's event", func(t *testing.T) {
		got, _, err := r.events.FindEventsWithTags(ctx, nil, mallory)
		require.NoError(t, err)
		assert.Empty(t, got)
	})
}

func TestCrossTenantCategoryIsolation(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	alice := newUser(t, r)
	mallory := newUser(t, r)

	// Alice's "other" default category.
	aliceOther, err := r.cats.FindIdByKind(ctx, alice, category.KindOther)
	require.NoError(t, err)

	t.Run("mallory cannot load alice's category", func(t *testing.T) {
		_, err := r.cats.FindByIdForUser(ctx, aliceOther, mallory)
		assert.Error(t, err)
	})

	t.Run("mallory cannot delete alice's category", func(t *testing.T) {
		// A custom (deletable) category of Alice.
		require.NoError(t, r.cats.Create(ctx, &category.Category{Category: "enc", Color: "#fff", Kind: category.KindCustom, IdUser: alice}))
		aliceCat, err := r.cats.FindIdByKind(ctx, alice, category.KindCustom)
		require.NoError(t, err)

		err = r.cats.Delete(ctx, aliceCat, mallory, false)
		assert.Error(t, err)

		_, err = r.cats.FindByIdForUser(ctx, aliceCat, alice)
		assert.NoError(t, err, "alice's category must survive")
	})

	t.Run("mallory's tagsId cannot reference alice's tags", func(t *testing.T) {
		// Create a tag in alice's "other" category.
		aliceTag, err := r.cats.CreateTag(ctx, "enc-tag", aliceOther, nil)
		require.NoError(t, err)

		err = r.cats.CheckTagsBelongToUser(ctx, []uint{aliceTag}, mallory)
		assert.Error(t, err)

		err = r.cats.CheckTagsBelongToUser(ctx, []uint{aliceTag}, alice)
		assert.NoError(t, err)
	})
}

func TestCrossTenantPersonIsolation(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	alice := newUser(t, r)
	mallory := newUser(t, r)

	alicePersonCat, err := r.cats.FindIdByKind(ctx, alice, category.KindPerson)
	require.NoError(t, err)
	require.NoError(t, r.person.CreatePersonWithTags(ctx,
		r.enc(t, "Jane", alice), r.enc(t, "Doe", alice), r.enc(t, "JaneDoe", alice),
		alicePersonCat, nil, alice))

	persons, _, err := r.person.FindPersonsWithTagsAndCategories(ctx, alice)
	require.NoError(t, err)
	require.Len(t, persons, 1)
	var personID uint
	for id := range persons {
		personID = id
	}

	t.Run("mallory cannot delete alice's person", func(t *testing.T) {
		err := r.person.DeletePerson(ctx, personID, mallory)
		assert.Error(t, err)

		got, _, err := r.person.FindPersonsWithTagsAndCategories(ctx, alice)
		require.NoError(t, err)
		assert.Len(t, got, 1, "alice's person must survive")
	})

	t.Run("mallory cannot see alice's person", func(t *testing.T) {
		got, _, err := r.person.FindPersonsWithTagsAndCategories(ctx, mallory)
		require.NoError(t, err)
		assert.Empty(t, got)
	})
}
