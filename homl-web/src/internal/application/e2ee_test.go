package application_test

import (
	"context"
	"encoding/base64"
	"strings"
	"testing"
	"time"

	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/e2ee"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
	"github.com/alkariin/homl/homl-web/test/mocks"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

// testBlob is a well-formed client-encrypted payload (shape only: the server
// never decrypts E2EE values).
var testBlob = e2ee.Prefix + base64.StdEncoding.EncodeToString(make([]byte, 44))

var testIndex = strings.Repeat("ab", 16)
var testKeyCheck = strings.Repeat("cd", 32)

func newE2EEService(repo *mocks.MockE2EERepo) application.E2EEService {
	return application.NewE2EEService(&application.E2EEConfig{E2EERepository: repo})
}

func TestE2EEMigrate(t *testing.T) {
	ctx := context.Background()

	validData := func() *e2ee.MigrationData {
		idx := testIndex
		return &e2ee.MigrationData{
			Categories: []e2ee.MigrationCategory{{Id: 1, Category: testBlob}},
			Tags:       []e2ee.MigrationTag{{Id: 2, Tag: testBlob, TagIndex: &idx}},
			Events:     []e2ee.MigrationEvent{{Id: 3, Description: testBlob}},
		}
	}

	t.Run("Rejects an unknown direction", func(t *testing.T) {
		repo := new(mocks.MockE2EERepo)
		err := newE2EEService(repo).Migrate(ctx, 1, "sideways", testKeyCheck, validData())

		assert.Error(t, err)
		repo.AssertNotCalled(t, "Migrate", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Enable rejects a malformed keyCheck", func(t *testing.T) {
		repo := new(mocks.MockE2EERepo)
		err := newE2EEService(repo).Migrate(ctx, 1, application.E2EEDirectionEnable, "nope", validData())

		assert.Error(t, err)
		repo.AssertNotCalled(t, "Migrate", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Enable rejects a plaintext category value", func(t *testing.T) {
		repo := new(mocks.MockE2EERepo)
		data := validData()
		data.Categories[0].Category = "Holidays"

		err := newE2EEService(repo).Migrate(ctx, 1, application.E2EEDirectionEnable, testKeyCheck, data)

		assert.Error(t, err)
		repo.AssertNotCalled(t, "Migrate", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Enable rejects a tag without tagIndex", func(t *testing.T) {
		repo := new(mocks.MockE2EERepo)
		data := validData()
		data.Tags[0].TagIndex = nil

		err := newE2EEService(repo).Migrate(ctx, 1, application.E2EEDirectionEnable, testKeyCheck, data)

		assert.Error(t, err)
		repo.AssertNotCalled(t, "Migrate", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Enable accepts an empty event description", func(t *testing.T) {
		repo := new(mocks.MockE2EERepo)
		data := validData()
		data.Events[0].Description = ""

		repo.On("Migrate", uint64(1), true, &testKeyCheck, data).Return(nil)

		err := newE2EEService(repo).Migrate(ctx, 1, application.E2EEDirectionEnable, testKeyCheck, data)

		assert.NoError(t, err)
		repo.AssertExpectations(t)
	})

	t.Run("Enable forwards a valid payload with the keyCheck", func(t *testing.T) {
		repo := new(mocks.MockE2EERepo)
		data := validData()

		repo.On("Migrate", uint64(1), true, &testKeyCheck, data).Return(nil)

		err := newE2EEService(repo).Migrate(ctx, 1, application.E2EEDirectionEnable, testKeyCheck, data)

		assert.NoError(t, err)
		repo.AssertExpectations(t)
	})

	t.Run("Disable re-normalizes names and drops indexes", func(t *testing.T) {
		repo := new(mocks.MockE2EERepo)
		idx := testIndex
		data := &e2ee.MigrationData{
			Categories: []e2ee.MigrationCategory{{Id: 1, Category: "summer TRIPS"}},
			Tags:       []e2ee.MigrationTag{{Id: 2, Tag: "movie night", TagIndex: &idx}},
			Events:     []e2ee.MigrationEvent{{Id: 3, Description: "any text stays as-is"}},
		}

		repo.On("Migrate", uint64(1), false, (*string)(nil), mock.MatchedBy(func(d *e2ee.MigrationData) bool {
			return d.Categories[0].Category == "Summer Trips" &&
				d.Tags[0].Tag == "Movie Night" &&
				d.Tags[0].TagIndex == nil &&
				d.Events[0].Description == "any text stays as-is"
		})).Return(nil)

		err := newE2EEService(repo).Migrate(ctx, 1, application.E2EEDirectionDisable, "", data)

		assert.NoError(t, err)
		repo.AssertExpectations(t)
	})

	t.Run("Disable rejects an empty tag name", func(t *testing.T) {
		repo := new(mocks.MockE2EERepo)
		data := &e2ee.MigrationData{
			Tags: []e2ee.MigrationTag{{Id: 2, Tag: "   "}},
		}

		err := newE2EEService(repo).Migrate(ctx, 1, application.E2EEDirectionDisable, "", data)

		assert.Error(t, err)
		repo.AssertNotCalled(t, "Migrate", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})
}

func TestE2EEPurge(t *testing.T) {
	repo := new(mocks.MockE2EERepo)
	repo.On("Purge", uint64(7)).Return(nil)

	err := newE2EEService(repo).Purge(context.Background(), 7)

	assert.NoError(t, err)
	repo.AssertExpectations(t)
}

/* --------------------- E2EE mode in the tag service --------------------- */

// e2eeCtx is a request context of an E2EE user, as set by the web middleware.
var e2eeCtx = e2ee.WithEnabled(context.Background(), true)

func TestCreateTagE2EE(t *testing.T) {
	t.Run("Stores the blob and index verbatim, without blacklist check", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		idx := testIndex

		catRepo.On("FindByIdForUser", uint(2), uint64(1)).
			Return(&category.Category{Id: 2, Kind: category.KindCustom}, nil)
		// The stored value is the client blob itself, not a server ciphertext.
		catRepo.On("CreateTag", testBlob, &idx, uint(2), (*uint)(nil)).Return(uint(1), nil)

		id, err := svc.CreateTag(e2eeCtx, 1, &category.Tag{Tag: testBlob, TagIndex: &idx, IdCategory: 2})

		assert.NoError(t, err)
		assert.Equal(t, uint(1), id)
		catRepo.AssertExpectations(t)
	})

	t.Run("Allows creating a tag in the date category", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		idx := testIndex

		catRepo.On("FindByIdForUser", uint(1), uint64(1)).
			Return(&category.Category{Id: 1, Kind: category.KindDate}, nil)
		catRepo.On("CreateTag", testBlob, &idx, uint(1), (*uint)(nil)).Return(uint(9), nil)

		_, err := svc.CreateTag(e2eeCtx, 1, &category.Tag{Tag: testBlob, TagIndex: &idx, IdCategory: 1})

		assert.NoError(t, err)
		catRepo.AssertExpectations(t)
	})

	t.Run("Rejects a plaintext tag value", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		idx := testIndex

		catRepo.On("FindByIdForUser", uint(2), uint64(1)).
			Return(&category.Category{Id: 2, Kind: category.KindCustom}, nil)

		_, err := svc.CreateTag(e2eeCtx, 1, &category.Tag{Tag: "Cinema", TagIndex: &idx, IdCategory: 2})

		assert.Error(t, err)
		catRepo.AssertNotCalled(t, "CreateTag", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Rejects a missing tagIndex", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		catRepo.On("FindByIdForUser", uint(2), uint64(1)).
			Return(&category.Category{Id: 2, Kind: category.KindCustom}, nil)

		_, err := svc.CreateTag(e2eeCtx, 1, &category.Tag{Tag: testBlob, IdCategory: 2})

		assert.Error(t, err)
		catRepo.AssertNotCalled(t, "CreateTag", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})
}

func TestCreateTagDropsStrayIndexForPlainUsers(t *testing.T) {
	catRepo := new(mocks.MockCategoriesRepo)
	svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

	idx := testIndex

	catRepo.On("FindByIdForUser", uint(2), uint64(1)).
		Return(&category.Category{Id: 2, Kind: category.KindCustom}, nil)
	// A non-E2EE client sneaking a tagIndex in must not get it stored.
	catRepo.On("CreateTag", mock.Anything, (*string)(nil), uint(2), (*uint)(nil)).Return(uint(1), nil)

	_, err := svc.CreateTag(context.Background(), 1, &category.Tag{Tag: "cinema", TagIndex: &idx, IdCategory: 2})

	assert.NoError(t, err)
	catRepo.AssertExpectations(t)
}

/* -------------------- E2EE mode in the events service ------------------- */

func TestEventsE2EE(t *testing.T) {
	newSvc := func(evtRepo *mocks.MockEventsRepo, catRepo *mocks.MockCategoriesRepo) application.EventsService {
		return application.NewEventsService(&application.ESConfig{
			EventsRepository:     evtRepo,
			CategoriesRepository: catRepo,
			Crypto:               testCrypto,
		})
	}

	t.Run("GetEvents forwards blind indexes verbatim and returns blobs untouched", func(t *testing.T) {
		evtRepo := new(mocks.MockEventsRepo)
		catRepo := new(mocks.MockCategoriesRepo)
		svc := newSvc(evtRepo, catRepo)

		evtRepo.On("FindEventsWithTags", []string{testIndex}, uint64(1)).
			Return(map[uint]event.Event{4: {Id: 4, Description: testBlob}}, map[uint][]category.Tag{}, nil)

		res, err := svc.GetEvents(e2eeCtx, 1, []string{testIndex, testIndex})

		assert.NoError(t, err)
		assert.Len(t, res, 1)
		// The description is the stored blob: the server must not decrypt it.
		assert.Equal(t, testBlob, res[0].Description)
		evtRepo.AssertExpectations(t)
	})

	t.Run("GetEvents rejects a tags filter that is not a blind index", func(t *testing.T) {
		evtRepo := new(mocks.MockEventsRepo)
		catRepo := new(mocks.MockCategoriesRepo)
		svc := newSvc(evtRepo, catRepo)

		_, err := svc.GetEvents(e2eeCtx, 1, []string{"Cinema"})

		assert.Error(t, err)
		evtRepo.AssertNotCalled(t, "FindEventsWithTags", mock.Anything, mock.Anything)
	})

	t.Run("CreateEvent skips the backend date tags", func(t *testing.T) {
		evtRepo := new(mocks.MockEventsRepo)
		catRepo := new(mocks.MockCategoriesRepo)
		svc := newSvc(evtRepo, catRepo)

		evt := &event.Event{Description: testBlob, Date: time.Date(2026, 7, 19, 0, 0, 0, 0, time.UTC)}

		catRepo.On("CheckTagsBelongToUser", []uint{8}, uint64(1)).Return(nil)
		// No date tags are built: E2EE clients attach their own.
		evtRepo.On("CreateEventWithTags", []category.Tag(nil), []uint{8}, evt, uint64(1)).Return(nil)

		err := svc.CreateEvent(e2eeCtx, 1, evt, []uint{8})

		assert.NoError(t, err)
		catRepo.AssertNotCalled(t, "FindIdByKind", mock.Anything, mock.Anything)
		evtRepo.AssertExpectations(t)
	})

	t.Run("CreateEvent rejects a plaintext description", func(t *testing.T) {
		evtRepo := new(mocks.MockEventsRepo)
		catRepo := new(mocks.MockCategoriesRepo)
		svc := newSvc(evtRepo, catRepo)

		evt := &event.Event{Description: "my secret note", Date: time.Date(2026, 7, 19, 0, 0, 0, 0, time.UTC)}

		catRepo.On("CheckTagsBelongToUser", []uint(nil), uint64(1)).Return(nil)

		err := svc.CreateEvent(e2eeCtx, 1, evt, nil)

		assert.Error(t, err)
		evtRepo.AssertNotCalled(t, "CreateEventWithTags", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})
}
