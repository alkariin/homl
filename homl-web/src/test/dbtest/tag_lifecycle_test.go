//go:build dbtest

package dbtest

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
)

// newCustomCategory inserts a custom category for the user and returns its id.
// The repository Create does not return the id, so the row is inserted raw.
func newCustomCategory(t *testing.T, r *repos, idUser uint64, encName string) uint {
	t.Helper()
	res, err := r.db.Exec(
		"INSERT INTO Categories (category, color, isLocked, kind, idUser) VALUES (?, ?, 0, 'custom', ?)",
		encName, "#123456", idUser,
	)
	require.NoError(t, err)
	id, err := res.LastInsertId()
	require.NoError(t, err)
	return uint(id)
}

// newEvent creates an event linked to the given tags and returns its id.
func newEvent(t *testing.T, r *repos, idUser uint64, tagsId []uint) uint {
	t.Helper()
	ctx := context.Background()
	require.NoError(t, r.events.CreateEventWithTags(ctx, nil, tagsId, &event.Event{Date: time.Now()}, idUser))
	var id uint
	require.NoError(t, r.db.Get(&id, "SELECT MAX(id) FROM Events WHERE idUser = ?", idUser))
	return id
}

func eventExists(t *testing.T, r *repos, id uint) bool {
	t.Helper()
	var n int
	require.NoError(t, r.db.Get(&n, "SELECT COUNT(*) FROM Events WHERE id = ?", id))
	return n == 1
}

// TestTagDeleteLifecycle exercises the usage counts and the delete semantics
// of a main tag: exclusive events are the ones whose only non-date tags
// belong to the deleted synonym group.
func TestTagDeleteLifecycle(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	alice := newUser(t, r)
	catA := newCustomCategory(t, r, alice, r.enc(t, "Hobbies", alice))
	catDate, err := r.cats.FindIdByKind(ctx, alice, category.KindDate)
	require.NoError(t, err)
	catPerson, err := r.cats.FindIdByKind(ctx, alice, category.KindPerson)
	require.NoError(t, err)

	alpha, err := r.cats.CreateTag(ctx, r.enc(t, "Alpha", alice), nil, catA, nil)
	require.NoError(t, err)
	beta, err := r.cats.CreateTag(ctx, r.enc(t, "Beta", alice), nil, catA, &alpha)
	require.NoError(t, err)
	gamma, err := r.cats.CreateTag(ctx, r.enc(t, "Gamma", alice), nil, catPerson, nil)
	require.NoError(t, err)
	dateTag, err := r.cats.CreateTag(ctx, r.enc(t, "2026", alice), nil, catDate, nil)
	require.NoError(t, err)

	// e1 only carries the group (plus a date tag): exclusive.
	// e2 reaches the group through the synonym but also has Gamma: not exclusive.
	e1 := newEvent(t, r, alice, []uint{alpha, dateTag})
	e2 := newEvent(t, r, alice, []uint{beta, gamma, dateTag})

	t.Run("tag usage counts the synonym group", func(t *testing.T) {
		usage, err := r.cats.GetTagUsage(ctx, alpha, alice)
		require.NoError(t, err)
		assert.Equal(t, 2, usage.Events)
		assert.Equal(t, 1, usage.ExclusiveEvents)
	})

	t.Run("category usage counts tags and events", func(t *testing.T) {
		usage, err := r.cats.GetCategoryUsage(ctx, catA, alice)
		require.NoError(t, err)
		assert.Equal(t, 2, usage.Tags)
		assert.Equal(t, 2, usage.Events)
		assert.Equal(t, 1, usage.ExclusiveEvents)
	})

	t.Run("deleting a synonym repoints its events to the main tag", func(t *testing.T) {
		require.NoError(t, r.cats.DeleteTag(ctx, beta, alice, false))

		var n int
		require.NoError(t, r.db.Get(&n, "SELECT COUNT(*) FROM EventsTags WHERE idEvent = ? AND idTag = ?", e2, alpha))
		assert.Equal(t, 1, n, "e2 must now be linked to the main tag")
	})

	t.Run("deleting a main tag with deleteEvents removes every event of the group", func(t *testing.T) {
		// e4 is not tagged with the group at all: it must survive.
		e4 := newEvent(t, r, alice, []uint{gamma, dateTag})

		require.NoError(t, r.cats.DeleteTag(ctx, alpha, alice, true))

		assert.False(t, eventExists(t, r, e1), "e1 carried the group: deleted")
		assert.False(t, eventExists(t, r, e2), "e2 carried the group (through the synonym) next to Gamma: deleted too")
		assert.True(t, eventExists(t, r, e4), "e4 never carried the group: preserved")
	})

	t.Run("deleting a main tag without deleteEvents preserves the events", func(t *testing.T) {
		delta, err := r.cats.CreateTag(ctx, r.enc(t, "Delta", alice), nil, catA, nil)
		require.NoError(t, err)
		e3 := newEvent(t, r, alice, []uint{delta, dateTag})

		require.NoError(t, r.cats.DeleteTag(ctx, delta, alice, false))

		assert.True(t, eventExists(t, r, e3), "e3 is preserved with its date tag only")
		var n int
		require.NoError(t, r.db.Get(&n, "SELECT COUNT(*) FROM EventsTags WHERE idEvent = ? AND idTag = ?", e3, dateTag))
		assert.Equal(t, 1, n)
	})
}

// TestMainTagMoveTakesSynonymsAlong checks that moving a main tag to another
// category through UpdateTag relocates its synonyms with it.
func TestMainTagMoveTakesSynonymsAlong(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	alice := newUser(t, r)
	catA := newCustomCategory(t, r, alice, r.enc(t, "Old", alice))
	catB := newCustomCategory(t, r, alice, r.enc(t, "New", alice))

	main, err := r.cats.CreateTag(ctx, r.enc(t, "Main", alice), nil, catA, nil)
	require.NoError(t, err)
	syn, err := r.cats.CreateTag(ctx, r.enc(t, "Syn", alice), nil, catA, &main)
	require.NoError(t, err)

	require.NoError(t, r.cats.UpdateTag(ctx, r.enc(t, "Main", alice), nil, catB, main, nil))

	moved, err := r.cats.FindTagForUser(ctx, syn, alice)
	require.NoError(t, err)
	assert.Equal(t, catB, moved.IdCategory, "the synonym must follow its main tag")
	require.NotNil(t, moved.IdParentTag)
	assert.Equal(t, main, *moved.IdParentTag, "the synonym link must survive the move")
}

// assertTagNameConflict checks that err is the 409 the client keys its
// message off, rather than the raw driver error behind a 500.
func assertTagNameConflict(t *testing.T, err error) {
	t.Helper()
	require.Error(t, err)
	assert.Equal(t, http.StatusConflict, apperror.Status(err))

	var appErr *apperror.Error
	require.ErrorAs(t, err, &appErr)
	assert.Equal(t, apperror.CodeTagNameConflict, appErr.Code)
	assert.NotEmpty(t, appErr.Message)
}

// TestTagNameConflicts covers every way a write can put two tags of the same
// name in one category. Tags is unique on (idCategory, tag) and the at-rest
// encryption is deterministic, so the names of one user always collide: each
// case must surface as a conflict the user can act on, leaving the tags
// exactly as they were.
func TestTagNameConflicts(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	t.Run("creating a name already used in the category", func(t *testing.T) {
		f := newDeleteFixture(t, r, "Hobbies")

		_, err := r.cats.CreateTag(ctx, r.enc(t, "Football", f.user), nil, f.doomed, nil)
		assertTagNameConflict(t, err)

		var n int
		require.NoError(t, r.db.Get(&n, "SELECT COUNT(*) FROM Tags WHERE idCategory = ?", f.doomed))
		assert.Equal(t, 2, n, "nothing was inserted")
	})

	t.Run("the same name in another category is legal", func(t *testing.T) {
		// Uniqueness is per category: this is what makes the collisions
		// above reachable in the first place.
		f := newDeleteFixture(t, r, "Hobbies")

		twin, err := r.cats.CreateTag(ctx, r.enc(t, "Football", f.user), nil, f.other, nil)
		require.NoError(t, err)
		assert.NotZero(t, twin)
	})

	t.Run("another user's identical name is legal", func(t *testing.T) {
		// Keys are derived per user, so the same plaintext yields a
		// different ciphertext and never collides across accounts.
		alice := newDeleteFixture(t, r, "Hobbies")
		bob := newDeleteFixture(t, r, "Hobbies")

		assert.NotEqual(t, r.enc(t, "Football", alice.user), r.enc(t, "Football", bob.user))
		_, err := r.cats.FindTagForUser(ctx, bob.main, bob.user)
		assert.NoError(t, err)
	})

	t.Run("renaming onto a name already used in the category", func(t *testing.T) {
		f := newDeleteFixture(t, r, "Hobbies")
		other, err := r.cats.CreateTag(ctx, r.enc(t, "Rugby", f.user), nil, f.doomed, nil)
		require.NoError(t, err)

		err = r.cats.UpdateTag(ctx, r.enc(t, "Football", f.user), nil, f.doomed, other, nil)
		assertTagNameConflict(t, err)

		unchanged, err := r.cats.FindTagForUser(ctx, other, f.user)
		require.NoError(t, err)
		assert.Equal(t, r.enc(t, "Rugby", f.user), unchanged.Tag, "the rename rolled back")
	})

	t.Run("moving into a category that already has the name", func(t *testing.T) {
		f := newDeleteFixture(t, r, "Hobbies")
		_, err := r.cats.CreateTag(ctx, r.enc(t, "Football", f.user), nil, f.other, nil)
		require.NoError(t, err)

		err = r.cats.UpdateTag(ctx, r.enc(t, "Football", f.user), nil, f.other, f.main, nil)
		assertTagNameConflict(t, err)

		stayed, err := r.cats.FindTagForUser(ctx, f.main, f.user)
		require.NoError(t, err)
		assert.Equal(t, f.doomed, stayed.IdCategory, "the tag never moved")
	})

	t.Run("a synonym following its main tag into a taken name", func(t *testing.T) {
		// The main tag's own name is free in the target category, so the
		// first statement succeeds: only the synonyms following it collide,
		// and the transaction must undo the move of the main tag too.
		f := newDeleteFixture(t, r, "Hobbies")
		_, err := r.cats.CreateTag(ctx, r.enc(t, "Foot", f.user), nil, f.other, nil)
		require.NoError(t, err)

		err = r.cats.UpdateTag(ctx, r.enc(t, "Football", f.user), nil, f.other, f.main, nil)
		assertTagNameConflict(t, err)

		stayed, err := r.cats.FindTagForUser(ctx, f.main, f.user)
		require.NoError(t, err)
		assert.Equal(t, f.doomed, stayed.IdCategory, "the main tag move rolled back")
		syn, err := r.cats.FindTagForUser(ctx, f.synonym, f.user)
		require.NoError(t, err)
		assert.Equal(t, f.doomed, syn.IdCategory, "and so did its synonym")
	})
}
