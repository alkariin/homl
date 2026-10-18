//go:build dbtest

package dbtest

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/homl/homl-web/internal/domain/category"
)

// TestTaglessEventListing covers an event without any tag — its last one
// deleted, or an E2EE event created without date tags: the listing starts
// from Events, so it still comes back, with no tag.
func TestTaglessEventListing(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	alice := newUser(t, r)
	mallory := newUser(t, r)
	other, err := r.cats.FindIdByKind(ctx, alice, category.KindOther)
	require.NoError(t, err)
	trip, err := r.cats.CreateTag(ctx, r.enc(t, "Trip", alice), nil, other, nil)
	require.NoError(t, err)

	bare := newEvent(t, r, alice, []uint{})
	tagged := newEvent(t, r, alice, []uint{trip})
	require.Empty(t, eventTagIds(t, r, bare))

	t.Run("it is listed, with no tag", func(t *testing.T) {
		events, tags, err := r.events.FindEventsWithTags(ctx, nil, alice)
		require.NoError(t, err)

		assert.Len(t, events, 2)
		assert.Contains(t, events, bare)
		assert.Empty(t, tags[bare])
		assert.Len(t, tags[tagged], 1)
	})

	t.Run("a tag filter leaves it out", func(t *testing.T) {
		events, _, err := r.events.FindEventsWithTags(ctx,
			[]string{r.enc(t, "Trip", alice)}, alice)
		require.NoError(t, err)

		assert.Len(t, events, 1)
		assert.Contains(t, events, tagged)
	})

	t.Run("another user still sees none of it", func(t *testing.T) {
		events, _, err := r.events.FindEventsWithTags(ctx, nil, mallory)
		require.NoError(t, err)

		assert.Empty(t, events)
	})
}
