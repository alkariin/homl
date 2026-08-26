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

// TestDeleteUserCascades is the guarantee behind the "delete my account"
// feature: one DELETE on the Users row must leave nothing of the user behind.
// It is asserted against the real schema because the sweep is done entirely by
// the ON DELETE CASCADE declarations, not by application code.
func TestDeleteUserCascades(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	alice := newUser(t, r)
	bob := newUser(t, r)

	// Alice owns a category tree (tag + synonym) and an event linked to it.
	aliceOther, err := r.cats.FindIdByKind(ctx, alice, category.KindOther)
	require.NoError(t, err)
	aliceTag, err := r.cats.CreateTag(ctx, r.enc(t, "Trip", alice), nil, aliceOther, nil)
	require.NoError(t, err)
	aliceSynonym, err := r.cats.CreateTag(ctx, r.enc(t, "Journey", alice), nil, aliceOther, &aliceTag)
	require.NoError(t, err)
	require.NoError(t, r.events.CreateEventWithTags(ctx, nil, []uint{aliceTag}, &event.Event{Description: r.enc(t, "secret", alice), Date: time.Now()}, alice))

	aliceEvents, _, err := r.events.FindEventsWithTags(ctx, nil, alice)
	require.NoError(t, err)
	require.Len(t, aliceEvents, 1)
	var aliceEventID uint
	for id := range aliceEvents {
		aliceEventID = id
	}

	// Bob's identical dataset is the control: the cascade must be scoped.
	bobOther, err := r.cats.FindIdByKind(ctx, bob, category.KindOther)
	require.NoError(t, err)
	bobTag, err := r.cats.CreateTag(ctx, r.enc(t, "Trip", bob), nil, bobOther, nil)
	require.NoError(t, err)
	require.NoError(t, r.events.CreateEventWithTags(ctx, nil, []uint{bobTag}, &event.Event{Description: r.enc(t, "kept", bob), Date: time.Now()}, bob))

	require.NoError(t, r.users.Delete(ctx, alice))

	count := func(query string, args ...interface{}) int {
		t.Helper()
		var n int
		require.NoError(t, r.db.Get(&n, query, args...))
		return n
	}

	assert.Zero(t, count("SELECT COUNT(*) FROM Users WHERE id = ?", alice), "the user row survived")
	assert.Zero(t, count("SELECT COUNT(*) FROM Categories WHERE idUser = ?", alice), "categories survived")
	assert.Zero(t, count("SELECT COUNT(*) FROM Events WHERE idUser = ?", alice), "events survived")
	assert.Zero(t, count("SELECT COUNT(*) FROM EventsTags WHERE idUser = ?", alice), "event-tag links survived")
	// Tags have no idUser: they hang off the category, so they are the row most
	// likely to be orphaned by a naive delete.
	assert.Zero(t, count("SELECT COUNT(*) FROM Tags WHERE id IN (?, ?)", aliceTag, aliceSynonym), "tags survived")
	assert.Zero(t, count("SELECT COUNT(*) FROM EventsTags WHERE idEvent = ?", aliceEventID), "links of the deleted event survived")

	// Bob is untouched.
	assert.Equal(t, 1, count("SELECT COUNT(*) FROM Users WHERE id = ?", bob))
	assert.Equal(t, 1, count("SELECT COUNT(*) FROM Events WHERE idUser = ?", bob))
	assert.Equal(t, 1, count("SELECT COUNT(*) FROM Tags WHERE id = ?", bobTag))

	// Deleting again reports the account as gone rather than succeeding twice.
	err = r.users.Delete(ctx, alice)
	assert.Error(t, err)
	assert.Equal(t, http.StatusNotFound, apperror.Status(err))
}
