package application_test

import (
	"context"
	"testing"

	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/test/mocks"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func TestCreateTag(t *testing.T) {
	ctx := context.Background()

	t.Run("Rejects a tag pointing at the Dates category", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		// Category 1 is the user's date category: its month/year tags are
		// managed by the backend only.
		catRepo.On("FindByIdForUser", uint(1), uint64(1)).
			Return(&category.Category{Id: 1, Kind: category.KindDate}, nil)

		_, err := svc.CreateTag(ctx, 1, &category.Tag{Tag: "Anything", IdCategory: 1})

		assert.Error(t, err)
		catRepo.AssertNotCalled(t, "CreateTag", mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Accepts a tag in the persons category (plain suggestion category)", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		catRepo.On("FindByIdForUser", uint(4), uint64(1)).
			Return(&category.Category{Id: 4, Kind: category.KindPerson}, nil)
		catRepo.On("CreateTag", mock.Anything, uint(4), (*uint)(nil)).Return(uint(1), nil)

		_, err := svc.CreateTag(ctx, 1, &category.Tag{Tag: "Anything", IdCategory: 4})

		assert.NoError(t, err)
		catRepo.AssertExpectations(t)
	})

	t.Run("Rejects a blacklisted tag (month name)", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		catRepo.On("FindByIdForUser", uint(2), uint64(1)).
			Return(&category.Category{Id: 2, Kind: category.KindCustom}, nil)

		// "january" -> title-cased "January" is in BLACKLIST_TAGS.
		_, err := svc.CreateTag(ctx, 1, &category.Tag{Tag: "january", IdCategory: 2})

		assert.Error(t, err)
		catRepo.AssertNotCalled(t, "CreateTag", mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Creates a valid tag (encrypted, title-cased)", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		catRepo.On("FindByIdForUser", uint(2), uint64(1)).
			Return(&category.Category{Id: 2, Kind: category.KindCustom}, nil)
		catRepo.On("CreateTag", mock.MatchedBy(func(enc string) bool {
			dec, err := testCrypto.Decrypt(enc, 1)
			return err == nil && dec == "Cinema"
		}), uint(2), (*uint)(nil)).Return(uint(1), nil)

		id, err := svc.CreateTag(ctx, 1, &category.Tag{Tag: "cinema", IdCategory: 2})

		assert.NoError(t, err)
		assert.Equal(t, uint(1), id)
		catRepo.AssertExpectations(t)
	})

	t.Run("Creates a synonym of a valid main tag of the same category", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		idParent := uint(10)

		catRepo.On("FindByIdForUser", uint(2), uint64(1)).
			Return(&category.Category{Id: 2, Kind: category.KindCustom}, nil)
		// The parent exists for the user, is a main tag (no parent of its own)
		// and lives in the same category.
		catRepo.On("FindTagForUser", idParent, uint64(1)).
			Return(&category.Tag{Id: idParent, Tag: "enc", IdCategory: 2, IdParentTag: nil}, nil)
		catRepo.On("CreateTag", mock.MatchedBy(func(enc string) bool {
			dec, err := testCrypto.Decrypt(enc, 1)
			return err == nil && dec == "Movies"
		}), uint(2), &idParent).Return(uint(11), nil)

		id, err := svc.CreateTag(ctx, 1, &category.Tag{Tag: "movies", IdCategory: 2, IdParentTag: &idParent})

		assert.NoError(t, err)
		assert.Equal(t, uint(11), id)
		catRepo.AssertExpectations(t)
	})

	t.Run("Rejects a synonym whose parent is itself a synonym", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		idParent := uint(10)
		idGrandParent := uint(4)

		catRepo.On("FindByIdForUser", uint(2), uint64(1)).
			Return(&category.Category{Id: 2, Kind: category.KindCustom}, nil)
		// The parent is already a synonym: depth is limited to one level.
		catRepo.On("FindTagForUser", idParent, uint64(1)).
			Return(&category.Tag{Id: idParent, IdCategory: 2, IdParentTag: &idGrandParent}, nil)

		_, err := svc.CreateTag(ctx, 1, &category.Tag{Tag: "movies", IdCategory: 2, IdParentTag: &idParent})

		assert.Error(t, err)
		catRepo.AssertNotCalled(t, "CreateTag", mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Rejects a synonym whose parent is in a different category", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		idParent := uint(10)

		catRepo.On("FindByIdForUser", uint(2), uint64(1)).
			Return(&category.Category{Id: 2, Kind: category.KindCustom}, nil)
		// The parent lives in category 1, the new synonym targets category 2.
		catRepo.On("FindTagForUser", idParent, uint64(1)).
			Return(&category.Tag{Id: idParent, IdCategory: 1, IdParentTag: nil}, nil)

		_, err := svc.CreateTag(ctx, 1, &category.Tag{Tag: "movies", IdCategory: 2, IdParentTag: &idParent})

		assert.Error(t, err)
		catRepo.AssertNotCalled(t, "CreateTag", mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Rejects a blacklisted synonym name", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		idParent := uint(10)

		catRepo.On("FindByIdForUser", uint(2), uint64(1)).
			Return(&category.Category{Id: 2, Kind: category.KindCustom}, nil)

		// "january" -> title-cased "January" is in BLACKLIST_TAGS, synonym or not.
		_, err := svc.CreateTag(ctx, 1, &category.Tag{Tag: "january", IdCategory: 2, IdParentTag: &idParent})

		assert.Error(t, err)
		catRepo.AssertNotCalled(t, "CreateTag", mock.Anything, mock.Anything, mock.Anything)
	})
}

func TestUpdateTag(t *testing.T) {
	ctx := context.Background()

	t.Run("Rejects a tag being its own synonym", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		idTag := uint(7)

		// The tag exists and belongs to the user.
		catRepo.On("FindTagForUser", idTag, uint64(1)).
			Return(&category.Tag{Id: idTag, IdCategory: 2}, nil)
		catRepo.On("HasSynonyms", idTag).Return(false, nil)
		catRepo.On("FindByIdForUser", uint(2), uint64(1)).
			Return(&category.Category{Id: 2, Kind: category.KindCustom}, nil)

		err := svc.UpdateTag(ctx, 1, &category.Tag{Id: idTag, Tag: "cinema", IdCategory: 2, IdParentTag: &idTag})

		assert.Error(t, err)
		catRepo.AssertNotCalled(t, "UpdateTag", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Rejects turning a tag that has synonyms into a synonym", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		idTag := uint(7)
		idParent := uint(10)

		catRepo.On("FindTagForUser", idTag, uint64(1)).
			Return(&category.Tag{Id: idTag, IdCategory: 2}, nil)
		catRepo.On("FindByIdForUser", uint(2), uint64(1)).
			Return(&category.Category{Id: 2, Kind: category.KindCustom}, nil)
		// The tag already has synonyms of its own: depth would exceed one level.
		catRepo.On("HasSynonyms", idTag).Return(true, nil)

		err := svc.UpdateTag(ctx, 1, &category.Tag{Id: idTag, Tag: "cinema", IdCategory: 2, IdParentTag: &idParent})

		assert.Error(t, err)
		catRepo.AssertNotCalled(t, "UpdateTag", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Rejects updating a tag living in the Dates category", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		idTag := uint(7)

		// The tag lives in the date category: backend-managed, read-only.
		catRepo.On("FindTagForUser", idTag, uint64(1)).
			Return(&category.Tag{Id: idTag, IdCategory: 1}, nil)
		catRepo.On("FindByIdForUser", uint(1), uint64(1)).
			Return(&category.Category{Id: 1, Kind: category.KindDate}, nil)

		err := svc.UpdateTag(ctx, 1, &category.Tag{Id: idTag, Tag: "renamed", IdCategory: 2})

		assert.Error(t, err)
		catRepo.AssertNotCalled(t, "UpdateTag", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("Updates a valid tag (encrypted, title-cased)", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo, Crypto: testCrypto})

		idTag := uint(7)

		catRepo.On("FindTagForUser", idTag, uint64(1)).
			Return(&category.Tag{Id: idTag, IdCategory: 2}, nil)
		catRepo.On("FindByIdForUser", uint(2), uint64(1)).
			Return(&category.Category{Id: 2, Kind: category.KindCustom}, nil)
		catRepo.On("UpdateTag", mock.MatchedBy(func(enc string) bool {
			dec, err := testCrypto.Decrypt(enc, 1)
			return err == nil && dec == "Cinema"
		}), uint(2), idTag, (*uint)(nil)).Return(nil)

		err := svc.UpdateTag(ctx, 1, &category.Tag{Id: idTag, Tag: "cinema", IdCategory: 2})

		assert.NoError(t, err)
		catRepo.AssertExpectations(t)
	})
}

func TestDeleteTag(t *testing.T) {
	t.Run("Forwards arguments to the repository", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo})

		catRepo.On("FindTagForUser", uint(5), uint64(1)).
			Return(&category.Tag{Id: 5, IdCategory: 2}, nil)
		catRepo.On("FindByIdForUser", uint(2), uint64(1)).
			Return(&category.Category{Id: 2, Kind: category.KindCustom}, nil)
		catRepo.On("DeleteTag", uint(5), uint64(1)).Return(nil)

		err := svc.DeleteTag(context.Background(), 5, 1)

		assert.NoError(t, err)
		catRepo.AssertExpectations(t)
	})

	t.Run("Rejects deleting a tag living in the Dates category", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewTagsService(&application.TSConfig{CategoriesRepository: catRepo})

		catRepo.On("FindTagForUser", uint(5), uint64(1)).
			Return(&category.Tag{Id: 5, IdCategory: 1}, nil)
		catRepo.On("FindByIdForUser", uint(1), uint64(1)).
			Return(&category.Category{Id: 1, Kind: category.KindDate}, nil)

		err := svc.DeleteTag(context.Background(), 5, 1)

		assert.Error(t, err)
		catRepo.AssertNotCalled(t, "DeleteTag", mock.Anything, mock.Anything)
	})
}
