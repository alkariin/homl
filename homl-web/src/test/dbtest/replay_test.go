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

// A client replaying writes it made offline has to address what it created
// without refetching everything: the create operations hand back the id of
// the row they stored.
func TestCreateReturnsTheStoredId(t *testing.T) {
	r := setup(t)
	ctx := context.Background()
	u := newUser(t, r)

	t.Run("category", func(t *testing.T) {
		id, err := r.cats.Create(ctx, &category.Category{Category: r.enc(t, "Trips", u), Color: "#123456", IdUser: u})
		require.NoError(t, err)
		require.NotZero(t, id)

		stored, err := r.cats.FindByIdForUser(ctx, id, u)
		require.NoError(t, err)
		assert.Equal(t, r.enc(t, "Trips", u), stored.Category)
		assert.Equal(t, category.KindCustom, stored.Kind)
	})

	t.Run("event", func(t *testing.T) {
		other, err := r.cats.FindIdByKind(ctx, u, category.KindOther)
		require.NoError(t, err)
		tag, err := r.cats.CreateTag(ctx, r.enc(t, "Beach", u), nil, other, nil)
		require.NoError(t, err)

		id, err := r.events.CreateEventWithTags(ctx, nil, []uint{tag}, &event.Event{Description: "swim", Date: time.Now()}, u)
		require.NoError(t, err)
		require.NotZero(t, id)

		events, tags, err := r.events.FindEventsWithTags(ctx, nil, u)
		require.NoError(t, err)
		require.Contains(t, events, id)
		dec, err := r.aes.Decrypt(events[id].Description, u)
		require.NoError(t, err)
		assert.Equal(t, "swim", dec)
		require.Len(t, tags[id], 1)
		assert.Equal(t, tag, tags[id][0].Id)
	})
}

// PATCH /tags is full-state, so a client that is unsure whether its PATCH
// landed (the connection dropped before the answer) sends it again. MySQL
// counts changed rows, not matched ones, so the replay affects no row: that
// must read as success, not as a failure.
func TestUpdateTagReplayIsANoOp(t *testing.T) {
	r := setup(t)
	ctx := context.Background()
	u := newUser(t, r)

	other, err := r.cats.FindIdByKind(ctx, u, category.KindOther)
	require.NoError(t, err)
	beach, err := r.cats.CreateTag(ctx, r.enc(t, "Beach", u), nil, other, nil)
	require.NoError(t, err)
	shore, err := r.cats.CreateTag(ctx, r.enc(t, "Shore", u), nil, other, &beach)
	require.NoError(t, err)

	t.Run("a main tag, renamed then renamed again to the same name", func(t *testing.T) {
		for attempt := 1; attempt <= 2; attempt++ {
			require.NoError(t, r.cats.UpdateTag(ctx, r.enc(t, "Sea", u), nil, other, beach, nil), "attempt %d", attempt)
		}

		stored, err := r.cats.FindTagForUser(ctx, beach, u)
		require.NoError(t, err)
		assert.Equal(t, r.enc(t, "Sea", u), stored.Tag)
		assert.Equal(t, other, stored.IdCategory)
	})

	t.Run("a synonym left exactly as it is", func(t *testing.T) {
		require.NoError(t, r.cats.UpdateTag(ctx, r.enc(t, "Shore", u), nil, other, shore, &beach))

		stored, err := r.cats.FindTagForUser(ctx, shore, u)
		require.NoError(t, err)
		require.NotNil(t, stored.IdParentTag)
		assert.Equal(t, beach, *stored.IdParentTag)
	})
}

// The date tags of an event are looked up before its write transaction opens,
// and the ones the lookup misses are inserted by the write. Two writes of the
// same new month at once (two devices syncing together) both miss it: the
// second insert must then reuse the row the first one created instead of
// failing on the (idCategory, tag) unique key. The race is replayed here by
// creating the tag between the "lookup" and the write.
func TestDateTagCreatedMeanwhileIsReused(t *testing.T) {
	r := setup(t)
	ctx := context.Background()
	u := newUser(t, r)

	dates, err := r.cats.FindIdByKind(ctx, u, category.KindDate)
	require.NoError(t, err)
	// Left behind by the concurrent write, after this one's lookup missed it.
	june, err := r.cats.CreateTag(ctx, r.enc(t, "June", u), nil, dates, nil)
	require.NoError(t, err)

	idOf := func(t *testing.T, name string) uint {
		t.Helper()
		var ids []uint
		require.NoError(t, r.db.Select(&ids, "SELECT id FROM Tags WHERE idCategory = ? AND tag = ?", dates, r.enc(t, name, u)))
		require.Len(t, ids, 1, "exactly one %q tag", name)
		return ids[0]
	}
	linked := func(t *testing.T, idEvent uint) []uint {
		t.Helper()
		var ids []uint
		require.NoError(t, r.db.Select(&ids, "SELECT idTag FROM EventsTags WHERE idEvent = ?", idEvent))
		return ids
	}

	t.Run("on create", func(t *testing.T) {
		missed := []category.Tag{{Tag: "June", IdCategory: dates}, {Tag: "2031", IdCategory: dates}}

		id, err := r.events.CreateEventWithTags(ctx, missed, nil, &event.Event{Date: day(2031, time.June, 3)}, u)
		require.NoError(t, err)

		assert.Equal(t, june, idOf(t, "June"), "the existing tag is reused, not duplicated")
		assert.ElementsMatch(t, []uint{june, idOf(t, "2031")}, linked(t, id))
	})

	t.Run("on update", func(t *testing.T) {
		missed := []category.Tag{{Tag: "June", IdCategory: dates}, {Tag: "2032", IdCategory: dates}}
		id := newEvent(t, r, u, nil)

		require.NoError(t, r.events.UpdateEventWithTags(ctx, missed, nil, &event.Event{Id: id, Date: day(2032, time.June, 3)}, u))

		assert.Equal(t, june, idOf(t, "June"), "the existing tag is reused, not duplicated")
		assert.ElementsMatch(t, []uint{june, idOf(t, "2032")}, linked(t, id))
	})
}
