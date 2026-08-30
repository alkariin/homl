package application_test

import (
	"context"
	"testing"
	"time"

	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
	"github.com/alkariin/homl/homl-web/test/mocks"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func TestGetEvents(t *testing.T) {
	t.Run("Deduplicates the requested tag names before querying the repository", func(t *testing.T) {
		eventsRepo := new(mocks.MockEventsRepo)
		svc := application.NewEventsService(&application.ESConfig{
			EventsRepository: eventsRepo,
			Crypto:           testCrypto,
		})

		// "A" is requested twice (once lowercase): tags are normalized before
		// dedup and the repository matches events against ALL requested
		// names, so the duplicate must be dropped.
		eventsRepo.On("FindEventsWithTags", mock.MatchedBy(func(encTags []string) bool {
			if len(encTags) != 2 {
				return false
			}
			dec0, err0 := testCrypto.Decrypt(encTags[0], 1)
			dec1, err1 := testCrypto.Decrypt(encTags[1], 1)
			return err0 == nil && err1 == nil && dec0 == "A" && dec1 == "A-Different"
		}), uint64(1)).Return(map[uint]event.Event{}, map[uint][]category.Tag{}, nil)

		res, err := svc.GetEvents(context.Background(), 1, []string{"A", "a-different", "a"})

		assert.NoError(t, err)
		assert.Empty(t, res)
		eventsRepo.AssertExpectations(t)
	})

	t.Run("Normalizes the requested tags to title case before encrypting", func(t *testing.T) {
		eventsRepo := new(mocks.MockEventsRepo)
		svc := application.NewEventsService(&application.ESConfig{
			EventsRepository: eventsRepo,
			Crypto:           testCrypto,
		})

		// Stored tags are title-cased on creation: the search terms must get
		// the exact same normalization whatever casing the user typed.
		eventsRepo.On("FindEventsWithTags", mock.MatchedBy(func(encTags []string) bool {
			if len(encTags) != 1 {
				return false
			}
			dec, err := testCrypto.Decrypt(encTags[0], 1)
			return err == nil && dec == "Movie Night"
		}), uint64(1)).Return(map[uint]event.Event{}, map[uint][]category.Tag{}, nil)

		_, err := svc.GetEvents(context.Background(), 1, []string{"movie NIGHT"})

		assert.NoError(t, err)
		eventsRepo.AssertExpectations(t)
	})

	t.Run("Returns the events newest first, latest created first on the same day", func(t *testing.T) {
		eventsRepo := new(mocks.MockEventsRepo)
		svc := application.NewEventsService(&application.ESConfig{
			EventsRepository: eventsRepo,
			Crypto:           testCrypto,
		})

		day := func(d int) time.Time {
			return time.Date(2026, time.August, d, 0, 0, 0, 0, time.UTC)
		}
		encrypted := func(s string) string {
			enc, err := testCrypto.Encrypt(s, 1)
			assert.NoError(t, err)
			return enc
		}
		// Ids follow the creation order, which does not match the dates: an
		// event created later for a past day (id 3) and an event whose date
		// was edited forward (id 1) must both move to their date's slot,
		// most recent date first.
		eventsRepo.On("FindEventsWithTags", mock.Anything, uint64(1)).Return(map[uint]event.Event{
			1: {Id: 1, Description: encrypted("moved forward"), Date: day(20)},
			2: {Id: 2, Description: encrypted("same day, created first"), Date: day(10)},
			3: {Id: 3, Description: encrypted("backdated"), Date: day(5)},
			4: {Id: 4, Description: encrypted("same day, created second"), Date: day(10)},
		}, map[uint][]category.Tag{}, nil)

		res, err := svc.GetEvents(context.Background(), 1, nil)

		assert.NoError(t, err)
		ids := make([]uint, 0, len(res))
		for _, r := range res {
			ids = append(ids, r.Id)
		}
		assert.Equal(t, []uint{1, 4, 2, 3}, ids)
	})
}

func TestCreateEvent(t *testing.T) {
	ctx := context.Background()
	date := time.Date(1993, time.December, 1, 0, 0, 0, 0, time.UTC)

	t.Run("Builds fresh month and year tags when none exist yet", func(t *testing.T) {
		eventsRepo := new(mocks.MockEventsRepo)
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewEventsService(&application.ESConfig{
			EventsRepository:     eventsRepo,
			CategoriesRepository: catRepo,
			Crypto:               testCrypto,
		})

		catRepo.On("CheckTagsBelongToUser", []uint{}, uint64(1)).Return(nil)
		catRepo.On("FindIdByKind", uint64(1), category.KindDate).Return(uint(3), nil)
		// No existing tag for either the month or the year.
		catRepo.On("FindTagIdByTagAndIdCategory", mock.Anything, uint(3)).Return(uint(0), nil)

		eventsRepo.On("CreateEventWithTags",
			mock.MatchedBy(func(tags []category.Tag) bool {
				return len(tags) == 2 &&
					tags[0].Tag == "December" && tags[0].IdCategory == 3 &&
					tags[1].Tag == "1993" && tags[1].IdCategory == 3
			}),
			mock.Anything, mock.Anything, uint64(1),
		).Return(nil)

		err := svc.CreateEvent(ctx, 1, &event.Event{Date: date}, []uint{})

		assert.NoError(t, err)
		eventsRepo.AssertExpectations(t)
	})

	t.Run("Reuses existing tag ids when the month/year tags already exist", func(t *testing.T) {
		eventsRepo := new(mocks.MockEventsRepo)
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewEventsService(&application.ESConfig{
			EventsRepository:     eventsRepo,
			CategoriesRepository: catRepo,
			Crypto:               testCrypto,
		})

		catRepo.On("CheckTagsBelongToUser", []uint{}, uint64(1)).Return(nil)
		catRepo.On("FindIdByKind", uint64(1), category.KindDate).Return(uint(3), nil)
		catRepo.On("FindTagIdByTagAndIdCategory", mock.Anything, uint(3)).Return(uint(77), nil)

		eventsRepo.On("CreateEventWithTags",
			mock.MatchedBy(func(tags []category.Tag) bool {
				// When a tag already exists, only its id is forwarded.
				return len(tags) == 2 &&
					tags[0].Id == 77 && tags[0].Tag == "" &&
					tags[1].Id == 77 && tags[1].Tag == ""
			}),
			mock.Anything, mock.Anything, uint64(1),
		).Return(nil)

		err := svc.CreateEvent(ctx, 1, &event.Event{Date: date}, []uint{})

		assert.NoError(t, err)
		eventsRepo.AssertExpectations(t)
	})
}

func TestDeleteEvent(t *testing.T) {
	t.Run("Forwards the id and the owner to the repository", func(t *testing.T) {
		eventsRepo := new(mocks.MockEventsRepo)
		svc := application.NewEventsService(&application.ESConfig{EventsRepository: eventsRepo})

		eventsRepo.On("Delete", uint(12), uint64(1)).Return(nil)

		err := svc.DeleteEvent(context.Background(), 12, 1)

		assert.NoError(t, err)
		eventsRepo.AssertExpectations(t)
	})
}
