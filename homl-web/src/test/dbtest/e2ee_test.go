//go:build dbtest

package dbtest

import (
	"context"
	"encoding/base64"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/e2ee"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/persistence"
)

// blob returns a distinct well-formed client payload (the server never
// decrypts E2EE values, only their shape matters here).
func blob(seed byte) string {
	raw := make([]byte, 44)
	raw[0] = seed
	return e2ee.Prefix + base64.StdEncoding.EncodeToString(raw)
}

// index returns a distinct well-formed blind index.
func index(seed string) string {
	return (seed + strings.Repeat("0", 32))[:32]
}

// fetchAll reads the user's current rows into a MigrationData skeleton, the
// way the client builds its migration payload.
func fetchAll(t *testing.T, r *repos, e2eeRepo e2ee.Repository, idUser uint64) *e2ee.MigrationData {
	t.Helper()
	ctx := context.Background()
	data := &e2ee.MigrationData{}

	var catIds []uint
	require.NoError(t, r.db.SelectContext(ctx, &catIds, "SELECT id FROM Categories WHERE idUser = ?", idUser))
	for _, id := range catIds {
		data.Categories = append(data.Categories, e2ee.MigrationCategory{Id: id})
	}

	var tagIds []uint
	require.NoError(t, r.db.SelectContext(ctx, &tagIds, "SELECT t.id FROM Tags t INNER JOIN Categories c ON t.idCategory = c.id WHERE c.idUser = ?", idUser))
	for _, id := range tagIds {
		data.Tags = append(data.Tags, e2ee.MigrationTag{Id: id})
	}

	var eventIds []uint
	require.NoError(t, r.db.SelectContext(ctx, &eventIds, "SELECT id FROM Events WHERE idUser = ?", idUser))
	for _, id := range eventIds {
		data.Events = append(data.Events, e2ee.MigrationEvent{Id: id})
	}

	return data
}

func TestE2EEMigrateLifecycle(t *testing.T) {
	r := setup(t)
	ctx := context.Background()
	e2eeRepo := persistence.NewE2EERepository(r.db, r.aes)

	alice := newUser(t, r)

	// Alice has one custom tag and one event before enabling E2EE.
	aliceOther, err := r.cats.FindIdByKind(ctx, alice, category.KindOther)
	require.NoError(t, err)
	aliceTag, err := r.cats.CreateTag(ctx, r.enc(t, "Trip", alice), nil, aliceOther, nil)
	require.NoError(t, err)
	require.NoError(t, r.events.CreateEventWithTags(ctx, nil, []uint{aliceTag},
		&event.Event{Description: r.enc(t, "secret", alice), Date: time.Now()}, alice))

	enabled, err := e2eeRepo.IsEnabled(ctx, alice)
	require.NoError(t, err)
	require.False(t, enabled)

	// Build the enable payload: every stored row re-encrypted client-side.
	data := fetchAll(t, r, e2eeRepo, alice)
	for i := range data.Categories {
		data.Categories[i].Category = blob(byte(i))
	}
	for i := range data.Tags {
		idx := index("ab")
		data.Tags[i].Tag = blob(byte(0x10 + i))
		data.Tags[i].TagIndex = &idx
	}
	for i := range data.Events {
		data.Events[i].Description = blob(byte(0x20 + i))
	}
	keyCheck := strings.Repeat("cd", 32)

	t.Run("Enable conflicts when the id set does not match", func(t *testing.T) {
		short := *data
		short.Events = nil
		err := e2eeRepo.Migrate(ctx, alice, true, &keyCheck, &short)
		require.Error(t, err)
		assert.Equal(t, 409, apperror.Status(err))
	})

	t.Run("Enable swaps every value and flips the flag", func(t *testing.T) {
		require.NoError(t, e2eeRepo.Migrate(ctx, alice, true, &keyCheck, data))

		enabled, err := e2eeRepo.IsEnabled(ctx, alice)
		require.NoError(t, err)
		assert.True(t, enabled)

		var storedTag, storedKeyCheck string
		require.NoError(t, r.db.GetContext(ctx, &storedTag, "SELECT tag FROM Tags WHERE id = ?", aliceTag))
		assert.True(t, strings.HasPrefix(storedTag, e2ee.Prefix), "tag column must hold the client blob")
		require.NoError(t, r.db.GetContext(ctx, &storedKeyCheck, "SELECT e2eeKeyCheck FROM Users WHERE id = ?", alice))
		assert.Equal(t, keyCheck, storedKeyCheck)
	})

	t.Run("Enable again conflicts (idempotent retry detection)", func(t *testing.T) {
		err := e2eeRepo.Migrate(ctx, alice, true, &keyCheck, data)
		require.Error(t, err)
		assert.Equal(t, 409, apperror.Status(err))
	})

	t.Run("E2EE search matches on the blind index", func(t *testing.T) {
		e2eeCtx := e2ee.WithEnabled(ctx, true)
		events, tags, err := r.events.FindEventsWithTags(e2eeCtx, []string{index("ab")}, alice)
		require.NoError(t, err)
		assert.Len(t, events, 1)
		for _, evTags := range tags {
			for _, tg := range evTags {
				assert.True(t, strings.HasPrefix(tg.Tag, e2ee.Prefix), "tag names must be returned verbatim")
			}
		}
	})

	t.Run("Disable re-encrypts at rest and clears indexes", func(t *testing.T) {
		back := fetchAll(t, r, e2eeRepo, alice)
		for i := range back.Categories {
			back.Categories[i].Category = "Category " + strings.Repeat("x", i+1)
		}
		for i := range back.Tags {
			back.Tags[i].Tag = "Trip"
		}
		for i := range back.Events {
			back.Events[i].Description = "secret"
		}

		require.NoError(t, e2eeRepo.Migrate(ctx, alice, false, nil, back))

		enabled, err := e2eeRepo.IsEnabled(ctx, alice)
		require.NoError(t, err)
		assert.False(t, enabled)

		// The tag decrypts again with the at-rest keyring and its index is gone.
		var storedTag string
		var storedIndex *string
		require.NoError(t, r.db.QueryRowContext(ctx, "SELECT tag, tagIndex FROM Tags WHERE id = ?", aliceTag).Scan(&storedTag, &storedIndex))
		dec, err := r.aes.Decrypt(storedTag, alice)
		require.NoError(t, err)
		assert.Equal(t, "Trip", dec)
		assert.Nil(t, storedIndex)

		var storedKeyCheck *string
		require.NoError(t, r.db.GetContext(ctx, &storedKeyCheck, "SELECT e2eeKeyCheck FROM Users WHERE id = ?", alice))
		assert.Nil(t, storedKeyCheck)
	})
}

func TestE2EEPurgeResetsAccount(t *testing.T) {
	r := setup(t)
	ctx := context.Background()
	e2eeRepo := persistence.NewE2EERepository(r.db, r.aes)

	alice := newUser(t, r)

	t.Run("Purge conflicts for a non-E2EE user", func(t *testing.T) {
		err := e2eeRepo.Purge(ctx, alice)
		require.Error(t, err)
		assert.Equal(t, 409, apperror.Status(err))
	})

	// Enable E2EE with the default categories only.
	data := fetchAll(t, r, e2eeRepo, alice)
	for i := range data.Categories {
		data.Categories[i].Category = blob(byte(i))
	}
	keyCheck := strings.Repeat("ef", 32)
	require.NoError(t, e2eeRepo.Migrate(ctx, alice, true, &keyCheck, data))

	t.Run("Purge deletes the data and reseeds the defaults", func(t *testing.T) {
		require.NoError(t, e2eeRepo.Purge(ctx, alice))

		enabled, err := e2eeRepo.IsEnabled(ctx, alice)
		require.NoError(t, err)
		assert.False(t, enabled)

		// Default categories are back, readable with the at-rest keyring.
		cats, _, err := r.cats.GetAllCategoriesWithTags(ctx, alice)
		require.NoError(t, err)
		assert.NotEmpty(t, cats)

		var count int
		require.NoError(t, r.db.GetContext(ctx, &count, "SELECT COUNT(*) FROM Events WHERE idUser = ?", alice))
		assert.Zero(t, count)
	})
}
