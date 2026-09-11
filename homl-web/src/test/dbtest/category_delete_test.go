//go:build dbtest

package dbtest

import (
	"context"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
)

// Deleting a category offers three mutually exclusive outcomes, and this file
// pins all three against the real SQL:
//
//	moveTags=true                  the tags (synonym links intact) move to the
//	                               Other category, every event keeps them
//	moveTags=false deleteEvents=false  the tags are deleted, the events survive
//	                               stripped of them
//	moveTags=false deleteEvents=true   the tags and every event they tag go
//
// Together with the refusals (locked categories, other users' categories) they
// are the regression net for the delete dialog of the category screen.

func tagExists(t *testing.T, r *repos, id uint) bool {
	t.Helper()
	var n int
	require.NoError(t, r.db.Get(&n, "SELECT COUNT(*) FROM Tags WHERE id = ?", id))
	return n == 1
}

func categoryExists(t *testing.T, r *repos, id uint) bool {
	t.Helper()
	var n int
	require.NoError(t, r.db.Get(&n, "SELECT COUNT(*) FROM Categories WHERE id = ?", id))
	return n == 1
}

// eventTagIds returns the tags still linked to an event, so a deletion can be
// checked to have removed exactly the right links and no others.
func eventTagIds(t *testing.T, r *repos, idEvent uint) []uint {
	t.Helper()
	ids := []uint{}
	require.NoError(t, r.db.Select(&ids,
		"SELECT idTag FROM EventsTags WHERE idEvent = ? ORDER BY idTag", idEvent))
	return ids
}

// fixture is one user with the three default categories plus a custom one
// ("doomed") holding a main tag and its synonym — the shape every deletion
// test starts from.
type fixture struct {
	user    uint64
	doomed  uint // the custom category under test
	other   uint // the user's Other category, target of moveTags
	main    uint // main tag of the doomed category
	synonym uint // its synonym, same category
	person  uint // a tag of the (unrelated) person category
	date    uint // a date tag
}

func newDeleteFixture(t *testing.T, r *repos, name string) *fixture {
	t.Helper()
	ctx := context.Background()

	f := &fixture{user: newUser(t, r)}
	var err error
	f.other, err = r.cats.FindIdByKind(ctx, f.user, category.KindOther)
	require.NoError(t, err)
	catDate, err := r.cats.FindIdByKind(ctx, f.user, category.KindDate)
	require.NoError(t, err)
	catPerson, err := r.cats.FindIdByKind(ctx, f.user, category.KindPerson)
	require.NoError(t, err)

	f.doomed = newCustomCategory(t, r, f.user, r.enc(t, name, f.user))
	f.main, err = r.cats.CreateTag(ctx, r.enc(t, "Football", f.user), nil, f.doomed, nil)
	require.NoError(t, err)
	f.synonym, err = r.cats.CreateTag(ctx, r.enc(t, "Foot", f.user), nil, f.doomed, &f.main)
	require.NoError(t, err)
	f.person, err = r.cats.CreateTag(ctx, r.enc(t, "Jane", f.user), nil, catPerson, nil)
	require.NoError(t, err)
	f.date, err = r.cats.CreateTag(ctx, r.enc(t, "2026", f.user), nil, catDate, nil)
	require.NoError(t, err)
	return f
}

// TestCategoryDeleteMoveTags covers the default option of the dialog: nothing
// is lost, the tags simply change category.
func TestCategoryDeleteMoveTags(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	t.Run("relocates the tags and keeps every event intact", func(t *testing.T) {
		f := newDeleteFixture(t, r, "Hobbies")
		// e1 lives only off the doomed category, e2 mixes it with a person tag.
		e1 := newEvent(t, r, f.user, []uint{f.main, f.date})
		e2 := newEvent(t, r, f.user, []uint{f.synonym, f.person})

		require.NoError(t, r.cats.Delete(ctx, f.doomed, f.user, true, false))

		assert.False(t, categoryExists(t, r, f.doomed), "the category itself is gone")

		moved, err := r.cats.FindTagForUser(ctx, f.main, f.user)
		require.NoError(t, err)
		assert.Equal(t, f.other, moved.IdCategory)
		movedSyn, err := r.cats.FindTagForUser(ctx, f.synonym, f.user)
		require.NoError(t, err)
		assert.Equal(t, f.other, movedSyn.IdCategory)
		require.NotNil(t, movedSyn.IdParentTag)
		assert.Equal(t, f.main, *movedSyn.IdParentTag, "synonym links survive the move")

		assert.Equal(t, []uint{f.main, f.date}, eventTagIds(t, r, e1), "e1 keeps its tags")
		assert.Equal(t, []uint{f.synonym, f.person}, eventTagIds(t, r, e2), "e2 keeps its tags")
	})

	t.Run("ignores deleteEvents", func(t *testing.T) {
		// The dialog never sends both, but the repository must not delete
		// anything when asked to move: moveTags wins over deleteEvents.
		f := newDeleteFixture(t, r, "Sports")
		e1 := newEvent(t, r, f.user, []uint{f.main, f.date})

		require.NoError(t, r.cats.Delete(ctx, f.doomed, f.user, true, true))

		assert.True(t, eventExists(t, r, e1), "moving the tags must never delete events")
		assert.True(t, tagExists(t, r, f.main))
		moved, err := r.cats.FindTagForUser(ctx, f.main, f.user)
		require.NoError(t, err)
		assert.Equal(t, f.other, moved.IdCategory)
	})

	t.Run("an empty category is a legal no-op", func(t *testing.T) {
		user := newUser(t, r)
		empty := newCustomCategory(t, r, user, r.enc(t, "Empty", user))

		require.NoError(t, r.cats.Delete(ctx, empty, user, true, false))

		assert.False(t, categoryExists(t, r, empty))
	})
}

// TestCategoryDeleteKeepEvents covers the middle option: the tags go, the
// events stay — stripped of them, possibly down to their date alone.
func TestCategoryDeleteKeepEvents(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	f := newDeleteFixture(t, r, "Hobbies")
	e1 := newEvent(t, r, f.user, []uint{f.main, f.date})
	e2 := newEvent(t, r, f.user, []uint{f.synonym, f.person})
	e3 := newEvent(t, r, f.user, []uint{f.person, f.date})

	require.NoError(t, r.cats.Delete(ctx, f.doomed, f.user, false, false))

	t.Run("the tags and their synonyms are cascade-deleted", func(t *testing.T) {
		assert.False(t, categoryExists(t, r, f.doomed))
		assert.False(t, tagExists(t, r, f.main))
		assert.False(t, tagExists(t, r, f.synonym))
		assert.True(t, tagExists(t, r, f.person), "other categories are untouched")
		assert.True(t, tagExists(t, r, f.date))
	})

	t.Run("the events survive, stripped of the deleted tags", func(t *testing.T) {
		assert.True(t, eventExists(t, r, e1))
		assert.True(t, eventExists(t, r, e2))
		assert.True(t, eventExists(t, r, e3))

		assert.Equal(t, []uint{f.date}, eventTagIds(t, r, e1), "e1 is left date-only")
		assert.Equal(t, []uint{f.person}, eventTagIds(t, r, e2), "e2 keeps its person tag")
		assert.Equal(t, []uint{f.person, f.date}, eventTagIds(t, r, e3), "e3 never carried one")
	})

	t.Run("the events are still listed afterwards", func(t *testing.T) {
		// The listing joins through EventsTags, so an event left with its
		// date tags alone must still come back: that is what the user sees
		// after choosing to keep the events.
		events, _, err := r.events.FindEventsWithTags(ctx, nil, f.user)
		require.NoError(t, err)
		assert.Len(t, events, 3)
		assert.Contains(t, events, e1)
	})
}

// TestCategoryDeleteWithEvents covers the destructive option: every event
// tagged from the category goes with it, whatever else it carries.
func TestCategoryDeleteWithEvents(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	f := newDeleteFixture(t, r, "Hobbies")
	e1 := newEvent(t, r, f.user, []uint{f.main, f.date})
	e2 := newEvent(t, r, f.user, []uint{f.synonym, f.person})
	e3 := newEvent(t, r, f.user, []uint{f.person, f.date})

	require.NoError(t, r.cats.Delete(ctx, f.doomed, f.user, false, true))

	assert.False(t, eventExists(t, r, e1), "e1 carried a tag of the category")
	assert.False(t, eventExists(t, r, e2), "e2 carried one through the synonym")
	assert.True(t, eventExists(t, r, e3), "e3 never carried one: preserved")

	assert.Equal(t, []uint{f.person, f.date}, eventTagIds(t, r, e3), "and keeps its own tags")
	assert.True(t, tagExists(t, r, f.person), "the tags of other categories survive")
	assert.True(t, tagExists(t, r, f.date))

	t.Run("the links of the deleted events are gone too", func(t *testing.T) {
		var n int
		require.NoError(t, r.db.Get(&n,
			"SELECT COUNT(*) FROM EventsTags WHERE idEvent IN (?, ?)", e1, e2))
		assert.Zero(t, n)
	})

	t.Run("only the owner's events are touched", func(t *testing.T) {
		// The DELETE is scoped by idUser as well as by category: a second
		// user's events must be out of its reach even in the same tables.
		other := newDeleteFixture(t, r, "Untouched")
		kept := newEvent(t, r, other.user, []uint{other.main, other.date})

		victim := newDeleteFixture(t, r, "Doomed")
		require.NoError(t, r.cats.Delete(ctx, victim.doomed, victim.user, false, true))

		assert.True(t, eventExists(t, r, kept))
		assert.Equal(t, []uint{other.main, other.date}, eventTagIds(t, r, kept))
	})
}

// TestCategoryDeleteRefusals pins what a deletion must refuse, in all three
// modes, and that a refusal leaves the database exactly as it was.
func TestCategoryDeleteRefusals(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	modes := []struct {
		name         string
		moveTags     bool
		deleteEvents bool
	}{
		{"moveTags", true, false},
		{"keepEvents", false, false},
		{"deleteEvents", false, true},
	}

	t.Run("the locked default categories cannot be deleted", func(t *testing.T) {
		for _, kind := range []category.Kind{category.KindDate, category.KindOther} {
			f := newDeleteFixture(t, r, "Hobbies")
			locked, err := r.cats.FindIdByKind(ctx, f.user, kind)
			require.NoError(t, err)
			e1 := newEvent(t, r, f.user, []uint{f.main, f.date})

			for _, m := range modes {
				err := r.cats.Delete(ctx, locked, f.user, m.moveTags, m.deleteEvents)
				require.Error(t, err, "%s in %s mode", kind, m.name)
				assert.Equal(t, http.StatusForbidden, apperror.Status(err))
			}

			assert.True(t, categoryExists(t, r, locked))
			assert.True(t, eventExists(t, r, e1))
			assert.True(t, tagExists(t, r, f.date))
		}
	})

	t.Run("the person category is deletable", func(t *testing.T) {
		// Unlike date and other it is only a suggestion (migration 000003).
		f := newDeleteFixture(t, r, "Hobbies")
		person, err := r.cats.FindIdByKind(ctx, f.user, category.KindPerson)
		require.NoError(t, err)

		require.NoError(t, r.cats.Delete(ctx, person, f.user, true, false))

		assert.False(t, categoryExists(t, r, person))
		moved, err := r.cats.FindTagForUser(ctx, f.person, f.user)
		require.NoError(t, err)
		assert.Equal(t, f.other, moved.IdCategory)
	})

	t.Run("another user's category is out of reach", func(t *testing.T) {
		for _, m := range modes {
			alice := newDeleteFixture(t, r, "Alice")
			mallory := newUser(t, r)
			e1 := newEvent(t, r, alice.user, []uint{alice.main, alice.date})

			err := r.cats.Delete(ctx, alice.doomed, mallory, m.moveTags, m.deleteEvents)
			require.Error(t, err, "mode %s", m.name)
			assert.Equal(t, http.StatusNotFound, apperror.Status(err),
				"someone else's id must read as missing, not as forbidden")

			assert.True(t, categoryExists(t, r, alice.doomed))
			assert.True(t, tagExists(t, r, alice.main))
			assert.True(t, eventExists(t, r, e1))
		}
	})

	t.Run("an unknown category reads as not found", func(t *testing.T) {
		user := newUser(t, r)
		err := r.cats.Delete(ctx, 999999999, user, false, false)
		require.Error(t, err)
		assert.Equal(t, http.StatusNotFound, apperror.Status(err))
	})
}

// TestCategoryDeleteMoveTagsNameClash covers the one way a move can fail: Tags
// is unique on (idCategory, tag) and the at-rest encryption is deterministic,
// so moving a tag into Other while Other already holds the same name hits the
// unique key. It must surface as a 409 the user can act on — not as the raw
// driver error behind a 500 — and the whole delete being one transaction, the
// failure must leave the category, its tags and its events exactly as they
// were, never half-moved.
func TestCategoryDeleteMoveTagsNameClash(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	f := newDeleteFixture(t, r, "Hobbies")
	// Same name, other category: legal, since uniqueness is per category.
	clash, err := r.cats.CreateTag(ctx, r.enc(t, "Football", f.user), nil, f.other, nil)
	require.NoError(t, err)
	e1 := newEvent(t, r, f.user, []uint{f.main, f.date})

	err = r.cats.Delete(ctx, f.doomed, f.user, true, false)
	require.Error(t, err, "the unique key on (idCategory, tag) rejects the move")
	assert.Equal(t, http.StatusConflict, apperror.Status(err))

	var appErr *apperror.Error
	require.ErrorAs(t, err, &appErr)
	assert.Equal(t, apperror.CodeTagNameConflict, appErr.Code,
		"the client keys its message off the code, not the message string")
	assert.NotEmpty(t, appErr.Message)

	assert.True(t, categoryExists(t, r, f.doomed), "the category is kept")
	assert.True(t, tagExists(t, r, f.main))
	assert.True(t, tagExists(t, r, clash))
	assert.True(t, eventExists(t, r, e1))
	assert.Equal(t, []uint{f.main, f.date}, eventTagIds(t, r, e1))

	stayed, err := r.cats.FindTagForUser(ctx, f.main, f.user)
	require.NoError(t, err)
	assert.Equal(t, f.doomed, stayed.IdCategory, "the tag never moved")

	t.Run("the other two options still work", func(t *testing.T) {
		require.NoError(t, r.cats.Delete(ctx, f.doomed, f.user, false, false))
		assert.False(t, categoryExists(t, r, f.doomed))
		assert.True(t, eventExists(t, r, e1), "the events were kept")
		assert.Equal(t, []uint{f.date}, eventTagIds(t, r, e1))
	})
}

// TestCategoryUsageCounts pins the three numbers the delete dialog is built
// from: a wrong count offers the user the wrong choices.
func TestCategoryUsageCounts(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	t.Run("an empty category counts nothing", func(t *testing.T) {
		user := newUser(t, r)
		empty := newCustomCategory(t, r, user, r.enc(t, "Empty", user))

		usage, err := r.cats.GetCategoryUsage(ctx, empty, user)
		require.NoError(t, err)
		assert.Equal(t, 0, usage.Tags)
		assert.Equal(t, 0, usage.Events)
		assert.Equal(t, 0, usage.ExclusiveEvents)
	})

	t.Run("tags count synonyms, events count once", func(t *testing.T) {
		f := newDeleteFixture(t, r, "Hobbies")
		// e1 carries both tags of the category: still a single event.
		newEvent(t, r, f.user, []uint{f.main, f.synonym, f.date})

		usage, err := r.cats.GetCategoryUsage(ctx, f.doomed, f.user)
		require.NoError(t, err)
		assert.Equal(t, 2, usage.Tags, "the synonym counts as a tag")
		assert.Equal(t, 1, usage.Events, "an event with two of them counts once")
	})

	t.Run("a date tag does not save an event from being exclusive", func(t *testing.T) {
		f := newDeleteFixture(t, r, "Hobbies")
		newEvent(t, r, f.user, []uint{f.main, f.date})      // exclusive
		newEvent(t, r, f.user, []uint{f.synonym, f.person}) // saved by Jane
		newEvent(t, r, f.user, []uint{f.person, f.date})    // unrelated

		usage, err := r.cats.GetCategoryUsage(ctx, f.doomed, f.user)
		require.NoError(t, err)
		assert.Equal(t, 2, usage.Tags)
		assert.Equal(t, 2, usage.Events)
		assert.Equal(t, 1, usage.ExclusiveEvents,
			"only the event whose sole non-date tag lived in the category")
	})

	t.Run("another user's events are not counted", func(t *testing.T) {
		f := newDeleteFixture(t, r, "Hobbies")
		newEvent(t, r, f.user, []uint{f.main, f.date})
		other := newDeleteFixture(t, r, "Other")
		newEvent(t, r, other.user, []uint{other.main, other.date})

		usage, err := r.cats.GetCategoryUsage(ctx, f.doomed, f.user)
		require.NoError(t, err)
		assert.Equal(t, 1, usage.Events)
		assert.Equal(t, 1, usage.ExclusiveEvents)
	})
}
