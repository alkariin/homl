package application_test

import (
	"context"
	"errors"
	"testing"

	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/test/mocks"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func TestCreateCategory(t *testing.T) {
	t.Run("Encrypts and title-cases the name, then forwards to the repository", func(t *testing.T) {
		mockRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewCategoriesService(&application.CSConfig{CategoriesRepository: mockRepo, Crypto: testCrypto})

		// The service should title-case "noces" -> "Noces", encrypt it,
		// force IsLocked to false and keep the IdUser untouched.
		mockRepo.On("Create", mock.MatchedBy(func(c *category.Category) bool {
			dec, err := testCrypto.Decrypt(c.Category)
			return err == nil && dec == "Noces" && c.Color == "red" && !c.IsLocked && c.IdUser == 42
		})).Return(nil)

		err := svc.CreateCategory(context.Background(), &category.Category{Category: "noces", Color: "red", IdUser: 42})

		assert.NoError(t, err)
		mockRepo.AssertExpectations(t)
	})

	t.Run("Propagates repository errors", func(t *testing.T) {
		mockRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewCategoriesService(&application.CSConfig{CategoriesRepository: mockRepo, Crypto: testCrypto})

		mockRepo.On("Create", mock.Anything).Return(errors.New("db down"))

		err := svc.CreateCategory(context.Background(), &category.Category{Category: "Noces", Color: "red"})

		assert.Error(t, err)
		mockRepo.AssertExpectations(t)
	})
}

func TestUpdateCategory(t *testing.T) {
	t.Run("Forbids renaming a locked category", func(t *testing.T) {
		mockRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewCategoriesService(&application.CSConfig{CategoriesRepository: mockRepo, Crypto: testCrypto})

		oldEncrypted, _ := testCrypto.Encrypt("Dates")
		mockRepo.On("FindByIdForUser", uint(1), uint64(9)).Return(&category.Category{
			Id:       1,
			Category: oldEncrypted,
			IsLocked: true,
		}, nil)

		err := svc.UpdateCategory(context.Background(), &category.Category{Id: 1, Category: "Renamed", Color: "#ffffff", IdUser: 9})

		assert.Error(t, err)
		// Update must never be reached.
		mockRepo.AssertNotCalled(t, "Update", mock.Anything)
		mockRepo.AssertExpectations(t)
	})

	t.Run("Updates a non-locked category", func(t *testing.T) {
		mockRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewCategoriesService(&application.CSConfig{CategoriesRepository: mockRepo, Crypto: testCrypto})

		stored, _ := testCrypto.Encrypt("Holidays")
		mockRepo.On("FindByIdForUser", uint(2), uint64(9)).Return(&category.Category{
			Id:       2,
			Category: stored,
			IsLocked: false,
		}, nil)
		mockRepo.On("Update", mock.MatchedBy(func(c *category.Category) bool {
			dec, err := testCrypto.Decrypt(c.Category)
			return err == nil && dec == "Trips" && c.Color == "#000000"
		})).Return(nil)

		err := svc.UpdateCategory(context.Background(), &category.Category{Id: 2, Category: "Trips", Color: "#000000", IdUser: 9})

		assert.NoError(t, err)
		mockRepo.AssertExpectations(t)
	})
}

func TestGetCategories(t *testing.T) {
	t.Run("Decrypts names and returns them sorted by id", func(t *testing.T) {
		mockRepo := new(mocks.MockCategoriesRepo)
		svc := application.NewCategoriesService(&application.CSConfig{CategoriesRepository: mockRepo, Crypto: testCrypto})

		encA, _ := testCrypto.Encrypt("Dates")
		encB, _ := testCrypto.Encrypt("Persons")

		categories := map[uint]category.Category{
			2: {Id: 2, Category: encB, Color: "#60ccff", IsLocked: true},
			1: {Id: 1, Category: encA, Color: "#ffff60", IsLocked: true},
		}
		tags := map[uint][]category.TagDTO{
			1: {{Id: 10, Tag: "January"}},
		}
		mockRepo.On("GetAllCategoriesWithTags", uint64(7)).Return(categories, tags, nil)

		res, err := svc.GetCategories(context.Background(), 7)

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
		svc := application.NewCategoriesService(&application.CSConfig{CategoriesRepository: mockRepo, Crypto: testCrypto})

		mockRepo.On("Delete", uint(3), uint64(9), true).Return(nil)

		err := svc.DeleteCategory(context.Background(), 3, 9, true)

		assert.NoError(t, err)
		mockRepo.AssertExpectations(t)
	})
}
