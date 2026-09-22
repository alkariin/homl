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
