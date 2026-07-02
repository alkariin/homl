package application_test

import (
	"testing"

	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/crypto"
	"github.com/alkariin/homl/homl-web/internal/domain/tag"
	"github.com/alkariin/homl/homl-web/test/mocks"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func TestCreateTag(t *testing.T) {
	t.Run("Rejects a tag pointing at the Persons category", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		tagRepo := new(mocks.MockTagsRepo)
		svc := application.NewTagsService(&application.TSConfig{TagsRepository: tagRepo, CategoriesRepository: catRepo})

		// Persons category id = last date id + 1.
		catRepo.On("FindLastIdByIdUser", uint64(1)).Return(uint(3), nil)

		err := svc.CreateTag(1, &tag.Tag{Tag: "Anything", IdCategory: 4})

		assert.Error(t, err)
		tagRepo.AssertNotCalled(t, "Create", mock.Anything, mock.Anything)
	})

	t.Run("Rejects a blacklisted tag (month name)", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		tagRepo := new(mocks.MockTagsRepo)
		svc := application.NewTagsService(&application.TSConfig{TagsRepository: tagRepo, CategoriesRepository: catRepo})

		catRepo.On("FindLastIdByIdUser", uint64(1)).Return(uint(3), nil)

		// "january" -> title-cased "January" is in BLACKLIST_TAGS.
		err := svc.CreateTag(1, &tag.Tag{Tag: "january", IdCategory: 2})

		assert.Error(t, err)
		tagRepo.AssertNotCalled(t, "Create", mock.Anything, mock.Anything)
	})

	t.Run("Creates a valid tag (encrypted, title-cased)", func(t *testing.T) {
		catRepo := new(mocks.MockCategoriesRepo)
		tagRepo := new(mocks.MockTagsRepo)
		svc := application.NewTagsService(&application.TSConfig{TagsRepository: tagRepo, CategoriesRepository: catRepo})

		catRepo.On("FindLastIdByIdUser", uint64(1)).Return(uint(3), nil)
		catRepo.On("CheckLastIdByIdAndIdUser", uint64(1), uint(2)).Return(nil)
		tagRepo.On("Create", mock.MatchedBy(func(enc string) bool {
			dec, err := crypto.Decrypt(enc)
			return err == nil && dec == "Cinema"
		}), uint(2)).Return(nil)

		err := svc.CreateTag(1, &tag.Tag{Tag: "cinema", IdCategory: 2})

		assert.NoError(t, err)
		catRepo.AssertExpectations(t)
		tagRepo.AssertExpectations(t)
	})
}

func TestDeleteTag(t *testing.T) {
	t.Run("Forwards arguments to the repository", func(t *testing.T) {
		tagRepo := new(mocks.MockTagsRepo)
		svc := application.NewTagsService(&application.TSConfig{TagsRepository: tagRepo})

		tagRepo.On("Delete", uint(5), uint64(1)).Return(nil)

		err := svc.DeleteTag(5, 1)

		assert.NoError(t, err)
		tagRepo.AssertExpectations(t)
	})
}
