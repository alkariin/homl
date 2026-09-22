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
