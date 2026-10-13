//go:build dbtest

package dbtest

import (
	"context"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/persistence"
)

// The writes an offline client replays when it reconnects: a create whose
// answer was lost is sent again with the same clientId, and must hand back
// the first row instead of storing a second one.

func eventsService(r *repos) application.EventsService {
	return application.NewEventsService(&application.ESConfig{
		EventsRepository:     r.events,
		CategoriesRepository: r.cats,
		Crypto:               r.aes,
	})
}

func countEvents(t *testing.T, r *repos, idUser uint64) int {
	t.Helper()
	var n int
	require.NoError(t, r.db.Get(&n, "SELECT COUNT(*) FROM Events WHERE idUser = ?", idUser))
	return n
}

func TestCreateEventReplayHandsBackTheFirstRow(t *testing.T) {
	r := setup(t)
	ctx := context.Background()
	u := newUser(t, r)
	svc := eventsService(r)

	other, err := r.cats.FindIdByKind(ctx, u, category.KindOther)
	require.NoError(t, err)
	beach, err := r.cats.CreateTag(ctx, r.enc(t, "Beach", u), nil, other, nil)
	require.NoError(t, err)
	hike, err := r.cats.CreateTag(ctx, r.enc(t, "Hike", u), nil, other, nil)
	require.NoError(t, err)

	clientId := uuid.NewString()
	date := time.Date(2026, time.June, 3, 0, 0, 0, 0, time.UTC)

	id, created, err := svc.CreateEvent(ctx, u,
		&event.Event{Description: "swim", Date: date, ClientId: &clientId}, []uint{beach})
	require.NoError(t, err)
	require.True(t, created)

	// The replay carries another body: it is not applied.
	replayed, created, err := svc.CreateEvent(ctx, u,
		&event.Event{Description: "changed", Date: date, ClientId: &clientId}, []uint{hike})
	require.NoError(t, err)
	assert.False(t, created)
	assert.Equal(t, id, replayed)

	assert.Equal(t, 1, countEvents(t, r, u))
	events, tags, err := r.events.FindEventsWithTags(ctx, nil, u)
	require.NoError(t, err)
	description, err := r.aes.Decrypt(events[id].Description, u)
	require.NoError(t, err)
	assert.Equal(t, "swim", description)
	var regular []uint
	for _, tag := range tags[id] {
		if tag.IdCategory == other {
			regular = append(regular, tag.Id)
		}
	}
	assert.Equal(t, []uint{beach}, regular)

	// The same clientId is free for another user.
	stranger := newUser(t, r)
	_, created, err = svc.CreateEvent(ctx, stranger,
		&event.Event{Description: "theirs", Date: date, ClientId: &clientId}, nil)
	require.NoError(t, err)
	assert.True(t, created)
}

func TestConcurrentReplaysStoreOneRow(t *testing.T) {
	r := setup(t)
	ctx := context.Background()
	u := newUser(t, r)
	svc := eventsService(r)

	clientId := uuid.NewString()
	date := time.Date(2026, time.June, 3, 0, 0, 0, 0, time.UTC)

	const attempts = 6
	ids := make([]uint, attempts)
	createdCount := 0
	var mu sync.Mutex
	var wg sync.WaitGroup
	for i := range attempts {
		wg.Add(1)
		go func() {
			defer wg.Done()
			id, created, err := svc.CreateEvent(ctx, u,
				&event.Event{Description: "swim", Date: date, ClientId: &clientId}, nil)
			assert.NoError(t, err)
			mu.Lock()
			defer mu.Unlock()
			ids[i] = id
			if created {
				createdCount++
			}
		}()
	}
	wg.Wait()

	assert.Equal(t, 1, countEvents(t, r, u))
	assert.Equal(t, 1, createdCount)
	for _, id := range ids {
		assert.Equal(t, ids[0], id)
	}
}

func TestCreateWithoutClientIdStaysAsBefore(t *testing.T) {
	r := setup(t)
	ctx := context.Background()
	u := newUser(t, r)
	svc := eventsService(r)

	date := time.Date(2026, time.June, 3, 0, 0, 0, 0, time.UTC)
	for range 2 {
		_, created, err := svc.CreateEvent(ctx, u, &event.Event{Description: "swim", Date: date}, nil)
		require.NoError(t, err)
		assert.True(t, created)
	}
	assert.Equal(t, 2, countEvents(t, r, u), "no clientId, no deduplication")
}

func TestDataGeneration(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	t.Run("a new account gets one", func(t *testing.T) {
		u := newUser(t, r)
		settings, err := r.users.FindSettingsByIdUser(ctx, u)
		require.NoError(t, err)
		_, err = uuid.Parse(settings.DataGeneration)
		assert.NoError(t, err, "a UUID, got %q", settings.DataGeneration)

		other := newUser(t, r)
		otherSettings, err := r.users.FindSettingsByIdUser(ctx, other)
		require.NoError(t, err)
		assert.NotEqual(t, settings.DataGeneration, otherSettings.DataGeneration)
	})

	t.Run("an E2EE purge changes it", func(t *testing.T) {
		e2eeRepo := persistence.NewE2EERepository(r.db, r.aes)
		u := newUser(t, r)
		before, err := r.users.FindSettingsByIdUser(ctx, u)
		require.NoError(t, err)

		data := fetchAll(t, r, e2eeRepo, u)
		for i := range data.Categories {
			data.Categories[i].Category = blob(byte(i))
		}
		keyCheck := strings.Repeat("ef", 32)
		require.NoError(t, e2eeRepo.Migrate(ctx, u, true, &keyCheck, data))

		// A migration keeps the ids: same generation.
		migrated, err := r.users.FindSettingsByIdUser(ctx, u)
		require.NoError(t, err)
		assert.Equal(t, before.DataGeneration, migrated.DataGeneration)

		require.NoError(t, e2eeRepo.Purge(ctx, u))

		purged, err := r.users.FindSettingsByIdUser(ctx, u)
		require.NoError(t, err)
		assert.NotEqual(t, before.DataGeneration, purged.DataGeneration)
		_, err = uuid.Parse(purged.DataGeneration)
		assert.NoError(t, err)
	})
}
