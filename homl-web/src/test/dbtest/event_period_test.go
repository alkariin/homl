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

func day(y int, m time.Month, d int) time.Time {
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

// TestEventPeriodRoundTrip writes the three shapes of an event through the
// real repository and reads them back: a NULL endDate must come back nil (not
// a zero time), isOngoing must survive the tinyint(1) column, and an update
// must be able to clear either — the PATCH is full-state.
func TestEventPeriodRoundTrip(t *testing.T) {
	r := setup(t)
	ctx := context.Background()
	u := newUser(t, r)

	// Events are only reachable through their EventsTags rows, so each one
	// carries a tag.
	other, err := r.cats.FindIdByKind(ctx, u, category.KindOther)
	require.NoError(t, err)
	tag, err := r.cats.CreateTag(ctx, r.enc(t, "Trip", u), nil, other, nil)
	require.NoError(t, err)

	// Descriptions go in as plaintext: the repository encrypts them itself on
	// write (storedDescription) and hands the ciphertext back on read.
	start := day(2026, time.June, 3)
	end := day(2026, time.June, 18)
	shapes := []event.Event{
		{Description: "single", Date: start},
		{Description: "closed", Date: start, EndDate: &end},
		{Description: "open", Date: start, IsOngoing: true},
	}
	for i := range shapes {
		require.NoError(t, r.events.CreateEventWithTags(ctx, nil, []uint{tag}, &shapes[i], u))
	}

	// byDescription finds one of the events above in a fresh read.
	byDescription := func(t *testing.T, plain string) event.Event {
		t.Helper()
		events, _, err := r.events.FindEventsWithTags(ctx, nil, u)
		require.NoError(t, err)
		for _, e := range events {
			dec, err := r.aes.Decrypt(e.Description, u)
			require.NoError(t, err)
			if dec == plain {
				return e
			}
		}
		t.Fatalf("event %q not found", plain)
		return event.Event{}
	}

	single := byDescription(t, "single")
	assert.Nil(t, single.EndDate, "a single day has no end date")
	assert.False(t, single.IsOngoing)

	closed := byDescription(t, "closed")
	require.NotNil(t, closed.EndDate)
	assert.True(t, end.Equal(*closed.EndDate), "end date read back as %v", *closed.EndDate)
	assert.False(t, closed.IsOngoing)

	open := byDescription(t, "open")
	assert.Nil(t, open.EndDate, "an open period has no end date")
	assert.True(t, open.IsOngoing)

	t.Run("closing an open period", func(t *testing.T) {
		require.NoError(t, r.events.UpdateEventWithTags(ctx, nil, []uint{tag},
			&event.Event{Id: open.Id, Description: "open", Date: start, EndDate: &end}, u))

		got := byDescription(t, "open")
		require.NotNil(t, got.EndDate)
		assert.True(t, end.Equal(*got.EndDate))
		assert.False(t, got.IsOngoing, "isOngoing must be reset, not left as it was")
	})

	t.Run("reopening a closed period", func(t *testing.T) {
		require.NoError(t, r.events.UpdateEventWithTags(ctx, nil, []uint{tag},
			&event.Event{Id: closed.Id, Description: "closed", Date: start, IsOngoing: true}, u))

		got := byDescription(t, "closed")
		assert.Nil(t, got.EndDate, "endDate must be written back to NULL, not kept")
		assert.True(t, got.IsOngoing)
	})
}
