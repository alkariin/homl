//go:build dbtest

package dbtest

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

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

	t.Run("deleting a main tag with deleteEvents removes exclusive events only", func(t *testing.T) {
		require.NoError(t, r.cats.DeleteTag(ctx, alpha, alice, true))

		assert.False(t, eventExists(t, r, e1), "e1 had no other non-date tag: deleted")
		assert.True(t, eventExists(t, r, e2), "e2 still has Gamma: preserved")
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

// TestCategoryDeleteLifecycle checks the two deletion modes: moving the tags
// to the Other category, or deleting them with or without their exclusive
// events.
func TestCategoryDeleteLifecycle(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	alice := newUser(t, r)
	catDate, err := r.cats.FindIdByKind(ctx, alice, category.KindDate)
	require.NoError(t, err)
	catPerson, err := r.cats.FindIdByKind(ctx, alice, category.KindPerson)
	require.NoError(t, err)
	catOther, err := r.cats.FindIdByKind(ctx, alice, category.KindOther)
	require.NoError(t, err)

	gamma, err := r.cats.CreateTag(ctx, r.enc(t, "Gamma", alice), nil, catPerson, nil)
	require.NoError(t, err)
	dateTag, err := r.cats.CreateTag(ctx, r.enc(t, "2026", alice), nil, catDate, nil)
	require.NoError(t, err)

	t.Run("moveTags relocates the tags to the Other category", func(t *testing.T) {
		catB := newCustomCategory(t, r, alice, r.enc(t, "Doomed", alice))
		zeta, err := r.cats.CreateTag(ctx, r.enc(t, "Zeta", alice), nil, catB, nil)
		require.NoError(t, err)
		zetaSyn, err := r.cats.CreateTag(ctx, r.enc(t, "ZetaSyn", alice), nil, catB, &zeta)
		require.NoError(t, err)

		require.NoError(t, r.cats.Delete(ctx, catB, alice, true, false))

		moved, err := r.cats.FindTagForUser(ctx, zeta, alice)
		require.NoError(t, err)
		assert.Equal(t, catOther, moved.IdCategory)
		movedSyn, err := r.cats.FindTagForUser(ctx, zetaSyn, alice)
		require.NoError(t, err)
		assert.Equal(t, catOther, movedSyn.IdCategory)
		require.NotNil(t, movedSyn.IdParentTag)
		assert.Equal(t, zeta, *movedSyn.IdParentTag, "synonym links survive the move")
	})

	t.Run("deleteEvents removes the events exclusive to the category", func(t *testing.T) {
		catB := newCustomCategory(t, r, alice, r.enc(t, "Doomed2", alice))
		zeta, err := r.cats.CreateTag(ctx, r.enc(t, "Zeta2", alice), nil, catB, nil)
		require.NoError(t, err)

		e1 := newEvent(t, r, alice, []uint{zeta, dateTag})
		e2 := newEvent(t, r, alice, []uint{zeta, gamma})

		require.NoError(t, r.cats.Delete(ctx, catB, alice, false, true))

		assert.False(t, eventExists(t, r, e1), "e1 had no non-date tag outside the category: deleted")
		assert.True(t, eventExists(t, r, e2), "e2 still has Gamma: preserved")
	})

	t.Run("without deleteEvents the events are preserved", func(t *testing.T) {
		catB := newCustomCategory(t, r, alice, r.enc(t, "Doomed3", alice))
		zeta, err := r.cats.CreateTag(ctx, r.enc(t, "Zeta3", alice), nil, catB, nil)
		require.NoError(t, err)

		e1 := newEvent(t, r, alice, []uint{zeta, dateTag})

		require.NoError(t, r.cats.Delete(ctx, catB, alice, false, false))

		assert.True(t, eventExists(t, r, e1), "e1 is preserved with its date tag only")
	})
}
