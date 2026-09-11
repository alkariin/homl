package application_test

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/e2ee"
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

	t.Run("Carries the period fields through to the response", func(t *testing.T) {
		eventsRepo := new(mocks.MockEventsRepo)
		svc := application.NewEventsService(&application.ESConfig{
			EventsRepository: eventsRepo,
			Crypto:           testCrypto,
		})

		encrypted := func(s string) string {
			enc, err := testCrypto.Encrypt(s, 1)
			assert.NoError(t, err)
			return enc
		}
		start := time.Date(2026, time.June, 3, 0, 0, 0, 0, time.UTC)
		end := time.Date(2026, time.June, 18, 0, 0, 0, 0, time.UTC)
		// The response is rebuilt from the repository's event (the description
		// is decrypted on the way): the period fields must survive that copy.
		eventsRepo.On("FindEventsWithTags", mock.Anything, uint64(1)).Return(map[uint]event.Event{
			1: {Id: 1, Description: encrypted("closed"), Date: start, EndDate: &end},
			2: {Id: 2, Description: encrypted("open"), Date: start, IsOngoing: true},
		}, map[uint][]category.Tag{}, nil)

		res, err := svc.GetEvents(context.Background(), 1, nil)

		assert.NoError(t, err)
		byId := make(map[uint]event.GetEventsResponse, len(res))
		for _, r := range res {
			byId[r.Id] = r
		}
		if assert.NotNil(t, byId[1].EndDate, "closed period lost its end date") {
			assert.True(t, end.Equal(*byId[1].EndDate))
		}
		assert.False(t, byId[1].IsOngoing)
		assert.Equal(t, "closed", byId[1].Description)
		assert.Nil(t, byId[2].EndDate)
		assert.True(t, byId[2].IsOngoing, "open period lost its flag")
		assert.Equal(t, "open", byId[2].Description)
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

func june(d int) time.Time {
	return time.Date(2026, time.June, d, 0, 0, 0, 0, time.UTC)
}

func datePtr(t time.Time) *time.Time { return &t }

// tagNames collects the names of the tags a repository call is about to
// attach; a compared set, since the order carries no meaning.
func tagNames(tags []category.Tag) []string {
	names := make([]string, 0, len(tags))
	for _, tag := range tags {
		names = append(names, tag.Tag)
	}
	return names
}

// newPeriodService wires a service whose date category is id 3 with no
// existing date tag, so every date tag comes through as a name to create.
func newPeriodService(eventsRepo *mocks.MockEventsRepo, catRepo *mocks.MockCategoriesRepo) application.EventsService {
	catRepo.On("CheckTagsBelongToUser", []uint{}, uint64(1)).Return(nil)
	catRepo.On("FindIdByKind", uint64(1), category.KindDate).Return(uint(3), nil)
	catRepo.On("FindTagIdByTagAndIdCategory", mock.Anything, uint(3)).Return(uint(0), nil)
	return application.NewEventsService(&application.ESConfig{
		EventsRepository:     eventsRepo,
		CategoriesRepository: catRepo,
		Crypto:               testCrypto,
	})
}

// The period invariants are refused before anything is looked up or written,
// and in both modes: prepareEvent returns early for E2EE accounts, and the
// checks must not have gone with it — the period columns are cleartext for
// everyone. Create and update share the same matrix.
func TestPeriodValidation(t *testing.T) {
	modes := []struct {
		name string
		ctx  context.Context
	}{
		{"E2EE off", context.Background()},
		{"E2EE on", e2ee.WithEnabled(context.Background(), true)},
	}
	ops := []struct {
		name string
		run  func(svc application.EventsService, ctx context.Context, evt *event.Event) error
	}{
		{"CreateEvent", func(svc application.EventsService, ctx context.Context, evt *event.Event) error {
			return svc.CreateEvent(ctx, 1, evt, []uint{})
		}},
		{"UpdateEvent", func(svc application.EventsService, ctx context.Context, evt *event.Event) error {
			evt.Id = 9
			return svc.UpdateEvent(ctx, 1, evt, []uint{})
		}},
	}
	invalid := []struct {
		name string
		evt  event.Event
	}{
		{"an end date before the start date", event.Event{Date: june(18), EndDate: datePtr(june(3))}},
		{"an end date on an ongoing period", event.Event{Date: june(3), EndDate: datePtr(june(18)), IsOngoing: true}},
		{"a period longer than 100 years", event.Event{Date: june(3), EndDate: datePtr(june(3).AddDate(101, 0, 0))}},
	}

	for _, mode := range modes {
		for _, op := range ops {
			for _, tc := range invalid {
				t.Run(mode.name+"/"+op.name+" refuses "+tc.name, func(t *testing.T) {
					eventsRepo := new(mocks.MockEventsRepo)
					catRepo := new(mocks.MockCategoriesRepo)
					svc := application.NewEventsService(&application.ESConfig{
						EventsRepository:     eventsRepo,
						CategoriesRepository: catRepo,
						Crypto:               testCrypto,
					})

					evt := tc.evt
					err := op.run(svc, mode.ctx, &evt)

					assert.Equal(t, http.StatusBadRequest, apperror.Status(err))
					// Refused up front: not even the tag ownership check ran.
					catRepo.AssertNotCalled(t, "CheckTagsBelongToUser", mock.Anything, mock.Anything)
					eventsRepo.AssertNotCalled(t, "CreateEventWithTags", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
					eventsRepo.AssertNotCalled(t, "UpdateEventWithTags", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
				})
			}
		}
	}

	t.Run("E2EE on/a valid closed period goes through untouched, with no date tags built", func(t *testing.T) {
		eventsRepo := new(mocks.MockEventsRepo)
		catRepo := new(mocks.MockCategoriesRepo)
		catRepo.On("CheckTagsBelongToUser", []uint{}, uint64(1)).Return(nil)
		svc := application.NewEventsService(&application.ESConfig{
			EventsRepository:     eventsRepo,
			CategoriesRepository: catRepo,
			Crypto:               testCrypto,
		})

		eventsRepo.On("CreateEventWithTags", []category.Tag(nil), []uint{}, mock.MatchedBy(func(evt *event.Event) bool {
			return evt.EndDate != nil && evt.EndDate.Equal(june(18)) && !evt.IsOngoing
		}), uint64(1)).Return(nil)

		err := svc.CreateEvent(e2ee.WithEnabled(context.Background(), true), 1,
			&event.Event{Date: june(3), EndDate: datePtr(june(18))}, []uint{})

		assert.NoError(t, err)
		eventsRepo.AssertExpectations(t)
	})
}

func TestCreateEventPeriodTags(t *testing.T) {
	ctx := context.Background()

	t.Run("Stores a period ending on its start day as a single day", func(t *testing.T) {
		eventsRepo := new(mocks.MockEventsRepo)
		catRepo := new(mocks.MockCategoriesRepo)
		svc := newPeriodService(eventsRepo, catRepo)

		// One stored representation for a one-day event: the end date is
		// dropped, and the tags are the plain month/year pair.
		eventsRepo.On("CreateEventWithTags",
			mock.MatchedBy(func(tags []category.Tag) bool {
				return assert.ElementsMatch(t, []string{"June", "2026"}, tagNames(tags))
			}),
			[]uint{},
			mock.MatchedBy(func(evt *event.Event) bool { return evt.EndDate == nil && !evt.IsOngoing }),
			uint64(1),
		).Return(nil)

		// Same calendar day, even with a time part MySQL would truncate.
		end := time.Date(2026, time.June, 3, 15, 30, 0, 0, time.UTC)
		err := svc.CreateEvent(ctx, 1, &event.Event{Date: june(3), EndDate: &end}, []uint{})

		assert.NoError(t, err)
		eventsRepo.AssertExpectations(t)
	})

	t.Run("Attaches a tag for every month a closed period covers", func(t *testing.T) {
		eventsRepo := new(mocks.MockEventsRepo)
		catRepo := new(mocks.MockCategoriesRepo)
		svc := newPeriodService(eventsRepo, catRepo)

		eventsRepo.On("CreateEventWithTags",
			mock.MatchedBy(func(tags []category.Tag) bool {
				return assert.ElementsMatch(t, []string{"June", "July", "2026"}, tagNames(tags))
			}),
			[]uint{},
			mock.MatchedBy(func(evt *event.Event) bool {
				return evt.EndDate != nil && evt.EndDate.Equal(time.Date(2026, time.July, 5, 0, 0, 0, 0, time.UTC))
			}),
			uint64(1),
		).Return(nil)

		err := svc.CreateEvent(ctx, 1, &event.Event{
			Date:    june(28),
			EndDate: datePtr(time.Date(2026, time.July, 5, 0, 0, 0, 0, time.UTC)),
		}, []uint{})

		assert.NoError(t, err)
		eventsRepo.AssertExpectations(t)
	})

	t.Run("Attaches the Ongoing tag to an open period, from its start month only", func(t *testing.T) {
		eventsRepo := new(mocks.MockEventsRepo)
		catRepo := new(mocks.MockCategoriesRepo)
		svc := newPeriodService(eventsRepo, catRepo)

		eventsRepo.On("CreateEventWithTags",
			mock.MatchedBy(func(tags []category.Tag) bool {
				return assert.ElementsMatch(t, []string{"June", "2024", event.OngoingTag}, tagNames(tags))
			}),
			[]uint{},
			mock.MatchedBy(func(evt *event.Event) bool { return evt.EndDate == nil && evt.IsOngoing }),
			uint64(1),
		).Return(nil)

		err := svc.CreateEvent(ctx, 1, &event.Event{
			Date:      time.Date(2024, time.June, 3, 0, 0, 0, 0, time.UTC),
			IsOngoing: true,
		}, []uint{})

		assert.NoError(t, err)
		eventsRepo.AssertExpectations(t)
	})
}
