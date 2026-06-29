package category

import (
	"errors"
	"testing"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/mocks"
	"github.com/alkariin/homl/homl-web/internal/shared"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func TestCreateCategory(t *testing.T) {
	t.Run("Encrypts and title-cases the name, then forwards to the repository", func(t *testing.T) {
		mockRepo := new(mocks.MockCategoriesRepo)
		svc := NewCategoriesService(&CSConfig{CategoriesRepository: mockRepo})

		// The service should title-case "noces" -> "Noces", encrypt it,
		// force IsLocked to false and keep the IdUser untouched.
		mockRepo.On("Create", mock.MatchedBy(func(c *domain.Category) bool {
			dec, err := shared.Decrypt(c.Category)
			return err == nil && dec == "Noces" && c.Color == "red" && !c.IsLocked && c.IdUser == 42
		})).Return(nil)

		err := svc.CreateCategory(&domain.Category{Category: "noces", Color: "red", IdUser: 42})

		assert.NoError(t, err)
		mockRepo.AssertExpectations(t)
	})

	t.Run("Propagates repository errors", func(t *testing.T) {
		mockRepo := new(mocks.MockCategoriesRepo)
		svc := NewCategoriesService(&CSConfig{CategoriesRepository: mockRepo})

		mockRepo.On("Create", mock.Anything).Return(errors.New("db down"))

		err := svc.CreateCategory(&domain.Category{Category: "Noces", Color: "red"})

		assert.Error(t, err)
		mockRepo.AssertExpectations(t)
	})
}

func TestUpdateCategory(t *testing.T) {
	t.Run("Forbids renaming a locked category", func(t *testing.T) {
		mockRepo := new(mocks.MockCategoriesRepo)
		svc := NewCategoriesService(&CSConfig{CategoriesRepository: mockRepo})

		oldEncrypted, _ := shared.Encrypt("Dates")
		mockRepo.On("FindById", uint(1)).Return(&domain.Category{
			Id:       1,
			Category: oldEncrypted,
			IsLocked: true,
		}, nil)

		err := svc.UpdateCategory(&domain.Category{Id: 1, Category: "Renamed", Color: "#ffffff"})

		assert.Error(t, err)
		// Update must never be reached.
		mockRepo.AssertNotCalled(t, "Update", mock.Anything)
		mockRepo.AssertExpectations(t)
	})

	t.Run("Updates a non-locked category", func(t *testing.T) {
		mockRepo := new(mocks.MockCategoriesRepo)
		svc := NewCategoriesService(&CSConfig{CategoriesRepository: mockRepo})

		stored, _ := shared.Encrypt("Holidays")
		mockRepo.On("FindById", uint(2)).Return(&domain.Category{
			Id:       2,
			Category: stored,
			IsLocked: false,
		}, nil)
		mockRepo.On("Update", mock.MatchedBy(func(c *domain.Category) bool {
			dec, err := shared.Decrypt(c.Category)
			return err == nil && dec == "Trips" && c.Color == "#000000"
		})).Return(nil)

		err := svc.UpdateCategory(&domain.Category{Id: 2, Category: "Trips", Color: "#000000"})

		assert.NoError(t, err)
		mockRepo.AssertExpectations(t)
	})
}

func TestGetCategories(t *testing.T) {
	t.Run("Decrypts names and returns them sorted by id", func(t *testing.T) {
		mockRepo := new(mocks.MockCategoriesRepo)
		svc := NewCategoriesService(&CSConfig{CategoriesRepository: mockRepo})

		encA, _ := shared.Encrypt("Dates")
		encB, _ := shared.Encrypt("Persons")

		categories := map[uint]domain.Category{
			2: {Id: 2, Category: encB, Color: "#60ccff", IsLocked: true},
			1: {Id: 1, Category: encA, Color: "#ffff60", IsLocked: true},
		}
		tags := map[uint][]domain.TagDTO{
			1: {{Id: 10, Tag: "January"}},
		}
		mockRepo.On("GetAllCategoriesWithTags", uint64(7)).Return(categories, tags, nil)

		res, err := svc.GetCategories(7)

		assert.NoError(t, err)
		assert.Len(t, res, 2)
		// Sorted ascending by id.
		assert.Equal(t, uint(1), res[0].Id)
		assert.Equal(t, "Dates", res[0].Category)
		assert.Equal(t, "January", res[0].Tags[0].Tag)
		assert.Equal(t, uint(2), res[1].Id)
		assert.Equal(t, "Persons", res[1].Category)
		mockRepo.AssertExpectations(t)
	})
}

func TestDeleteCategory(t *testing.T) {
	t.Run("Forwards arguments to the repository", func(t *testing.T) {
		mockRepo := new(mocks.MockCategoriesRepo)
		svc := NewCategoriesService(&CSConfig{CategoriesRepository: mockRepo})

		mockRepo.On("Delete", uint(3), uint64(9), true).Return(nil)

		err := svc.DeleteCategory(3, 9, true)

		assert.NoError(t, err)
		mockRepo.AssertExpectations(t)
	})
}
