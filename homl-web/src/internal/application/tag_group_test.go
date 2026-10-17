package application_test

import (
	"context"
	"database/sql"
	"net/http"
	"testing"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/test/mocks"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func newTagGroupsService(repo *mocks.MockCategoriesRepo) application.TagGroupsService {
	return application.NewTagGroupsService(&application.TGSConfig{CategoriesRepository: repo, Crypto: testCrypto})
}

func TestCreateTagGroup(t *testing.T) {
	ctx := context.Background()

	t.Run("Stores the title-cased, encrypted name with the deduplicated members", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)

		catRepo.On("FindByIdForUser", uint(4), uint64(1)).
			Return(&category.Category{Id: 4, Kind: category.KindPerson}, nil)
		catRepo.On("CheckMainTagsInCategory", []uint{10, 11}, uint(4), uint64(1)).Return(nil)
		catRepo.On("CreateTagGroup", mock.MatchedBy(func(enc string) bool {
			dec, err := testCrypto.Decrypt(enc, 1)
			return err == nil && dec == "Close Family"
		}), (*string)(nil), uint(4), []uint{10, 11}).Return(uint(7), nil)

		id, err := newTagGroupsService(catRepo).CreateTagGroup(ctx, 1, &category.TagGroup{
			Name: "close family", IdCategory: 4, Members: []uint{10, 11, 10},
		})

		assert.NoError(t, err)
		assert.Equal(t, uint(7), id)
		catRepo.AssertExpectations(t)
	})

	t.Run("Rejects a group without members", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)

		catRepo.On("FindByIdForUser", uint(4), uint64(1)).
			Return(&category.Category{Id: 4, Kind: category.KindPerson}, nil)

		_, err := newTagGroupsService(catRepo).CreateTagGroup(ctx, 1, &category.TagGroup{
			Name: "Family", IdCategory: 4,
		})

		assert.Equal(t, http.StatusBadRequest, apperror.Status(err))
		catRepo.AssertNotCalled(t, "CreateTagGroup", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Rejects members that are not main tags of the category", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)

		catRepo.On("FindByIdForUser", uint(4), uint64(1)).
			Return(&category.Category{Id: 4, Kind: category.KindPerson}, nil)
		catRepo.On("CheckMainTagsInCategory", []uint{10, 99}, uint(4), uint64(1)).
			Return(apperror.NewBadRequest("The members must be main tags of the group's category"))

		_, err := newTagGroupsService(catRepo).CreateTagGroup(ctx, 1, &category.TagGroup{
			Name: "Family", IdCategory: 4, Members: []uint{10, 99},
		})

		assert.Equal(t, http.StatusBadRequest, apperror.Status(err))
		catRepo.AssertNotCalled(t, "CreateTagGroup", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Rejects the Dates category", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)

		catRepo.On("FindByIdForUser", uint(1), uint64(1)).
			Return(&category.Category{Id: 1, Kind: category.KindDate}, nil)

		_, err := newTagGroupsService(catRepo).CreateTagGroup(ctx, 1, &category.TagGroup{
			Name: "Summer", IdCategory: 1, Members: []uint{3},
		})

		assert.Equal(t, http.StatusBadRequest, apperror.Status(err))
		catRepo.AssertNotCalled(t, "CreateTagGroup", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Rejects a category of another user", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)

		catRepo.On("FindByIdForUser", uint(4), uint64(1)).
			Return(nil, apperror.NewNotFound("category", "4"))

		_, err := newTagGroupsService(catRepo).CreateTagGroup(ctx, 1, &category.TagGroup{
			Name: "Family", IdCategory: 4, Members: []uint{10},
		})

		assert.Equal(t, http.StatusBadRequest, apperror.Status(err))
		catRepo.AssertNotCalled(t, "CreateTagGroup", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Rejects a name reserved for the date tags", func(t *testing.T) {
		for _, name := range []string{"july", "ongoing", "2024"} {
			catRepo := new(mocks.MockCategoriesRepo)

			catRepo.On("FindByIdForUser", uint(4), uint64(1)).
				Return(&category.Category{Id: 4, Kind: category.KindPerson}, nil)
			catRepo.On("CheckMainTagsInCategory", []uint{10}, uint(4), uint64(1)).Return(nil)

			_, err := newTagGroupsService(catRepo).CreateTagGroup(ctx, 1, &category.TagGroup{
				Name: name, IdCategory: 4, Members: []uint{10},
			})

			assert.Equal(t, http.StatusBadRequest, apperror.Status(err), name)
			catRepo.AssertNotCalled(t, "CreateTagGroup", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
		}
	})

	t.Run("Drops a stray nameIndex from a non-E2EE client", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		idx := testIndex

		catRepo.On("FindByIdForUser", uint(4), uint64(1)).
			Return(&category.Category{Id: 4, Kind: category.KindPerson}, nil)
		catRepo.On("CheckMainTagsInCategory", []uint{10}, uint(4), uint64(1)).Return(nil)
		catRepo.On("CreateTagGroup", mock.Anything, (*string)(nil), uint(4), []uint{10}).Return(uint(7), nil)

		_, err := newTagGroupsService(catRepo).CreateTagGroup(ctx, 1, &category.TagGroup{
			Name: "Family", IdCategory: 4, Members: []uint{10}, NameIndex: &idx,
		})

		assert.NoError(t, err)
		catRepo.AssertExpectations(t)
	})
}

func TestCreateTagGroupE2EE(t *testing.T) {
	t.Run("Stores the blob and index verbatim", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		idx := testIndex

		catRepo.On("FindByIdForUser", uint(4), uint64(1)).
			Return(&category.Category{Id: 4, Kind: category.KindPerson}, nil)
		catRepo.On("CheckMainTagsInCategory", []uint{10}, uint(4), uint64(1)).Return(nil)
		catRepo.On("CreateTagGroup", testBlob, &idx, uint(4), []uint{10}).Return(uint(7), nil)

		_, err := newTagGroupsService(catRepo).CreateTagGroup(e2eeCtx, 1, &category.TagGroup{
			Name: testBlob, IdCategory: 4, Members: []uint{10}, NameIndex: &idx,
		})

		assert.NoError(t, err)
		catRepo.AssertExpectations(t)
	})

	t.Run("Rejects a plaintext name", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		idx := testIndex

		catRepo.On("FindByIdForUser", uint(4), uint64(1)).
			Return(&category.Category{Id: 4, Kind: category.KindPerson}, nil)
		catRepo.On("CheckMainTagsInCategory", []uint{10}, uint(4), uint64(1)).Return(nil)

		_, err := newTagGroupsService(catRepo).CreateTagGroup(e2eeCtx, 1, &category.TagGroup{
			Name: "Family", IdCategory: 4, Members: []uint{10}, NameIndex: &idx,
		})

		assert.Equal(t, http.StatusBadRequest, apperror.Status(err))
		catRepo.AssertNotCalled(t, "CreateTagGroup", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Rejects a missing nameIndex", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)

		catRepo.On("FindByIdForUser", uint(4), uint64(1)).
			Return(&category.Category{Id: 4, Kind: category.KindPerson}, nil)
		catRepo.On("CheckMainTagsInCategory", []uint{10}, uint(4), uint64(1)).Return(nil)

		_, err := newTagGroupsService(catRepo).CreateTagGroup(e2eeCtx, 1, &category.TagGroup{
			Name: testBlob, IdCategory: 4, Members: []uint{10},
		})

		assert.Equal(t, http.StatusBadRequest, apperror.Status(err))
		catRepo.AssertNotCalled(t, "CreateTagGroup", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Still rejects the Dates category", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		idx := testIndex

		catRepo.On("FindByIdForUser", uint(1), uint64(1)).
			Return(&category.Category{Id: 1, Kind: category.KindDate}, nil)

		_, err := newTagGroupsService(catRepo).CreateTagGroup(e2eeCtx, 1, &category.TagGroup{
			Name: testBlob, IdCategory: 1, Members: []uint{3}, NameIndex: &idx,
		})

		assert.Equal(t, http.StatusBadRequest, apperror.Status(err))
		catRepo.AssertNotCalled(t, "CreateTagGroup", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})
}

func TestUpdateTagGroup(t *testing.T) {
	ctx := context.Background()

	t.Run("Validates against the stored category, whatever the body says", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)

		catRepo.On("FindTagGroupForUser", uint(7), uint64(1)).
			Return(&category.TagGroup{Id: 7, IdCategory: 4}, nil)
		catRepo.On("FindByIdForUser", uint(4), uint64(1)).
			Return(&category.Category{Id: 4, Kind: category.KindPerson}, nil)
		catRepo.On("CheckMainTagsInCategory", []uint{12}, uint(4), uint64(1)).Return(nil)
		catRepo.On("UpdateTagGroup", mock.MatchedBy(func(enc string) bool {
			dec, err := testCrypto.Decrypt(enc, 1)
			return err == nil && dec == "Family"
		}), (*string)(nil), uint(7), []uint{12}).Return(nil)

		err := newTagGroupsService(catRepo).UpdateTagGroup(ctx, 1, &category.TagGroup{
			Id: 7, Name: "family", IdCategory: 99, Members: []uint{12},
		})

		assert.NoError(t, err)
		catRepo.AssertExpectations(t)
		catRepo.AssertNotCalled(t, "FindByIdForUser", uint(99), mock.Anything)
	})

	t.Run("Rejects a group of another user", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)

		catRepo.On("FindTagGroupForUser", uint(7), uint64(1)).Return(nil, sql.ErrNoRows)

		err := newTagGroupsService(catRepo).UpdateTagGroup(ctx, 1, &category.TagGroup{
			Id: 7, Name: "Family", Members: []uint{12},
		})

		assert.Equal(t, http.StatusBadRequest, apperror.Status(err))
		catRepo.AssertNotCalled(t, "UpdateTagGroup", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Rejects emptying the group", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)

		catRepo.On("FindTagGroupForUser", uint(7), uint64(1)).
			Return(&category.TagGroup{Id: 7, IdCategory: 4}, nil)
		catRepo.On("FindByIdForUser", uint(4), uint64(1)).
			Return(&category.Category{Id: 4, Kind: category.KindPerson}, nil)

		err := newTagGroupsService(catRepo).UpdateTagGroup(ctx, 1, &category.TagGroup{
			Id: 7, Name: "Family", Members: []uint{},
		})

		assert.Equal(t, http.StatusBadRequest, apperror.Status(err))
		catRepo.AssertNotCalled(t, "UpdateTagGroup", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})
}

func TestDeleteTagGroup(t *testing.T) {
	catRepo := new(mocks.MockCategoriesRepo)
	catRepo.On("DeleteTagGroup", uint(7), uint64(1)).Return(nil)

	err := newTagGroupsService(catRepo).DeleteTagGroup(context.Background(), 7, 1)

	assert.NoError(t, err)
	catRepo.AssertExpectations(t)
}
