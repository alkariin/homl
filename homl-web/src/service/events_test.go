package service

import (
	"testing"
	"time"

	"github.com/alkariin/homl/homl-web/model"
	"github.com/alkariin/homl/homl-web/repository/mocks"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func TestCreateEvent(t *testing.T) {
	date := time.Date(1993, time.December, 1, 0, 0, 0, 0, time.UTC)

	t.Run("Builds fresh month and year tags when none exist yet", func(t *testing.T) {
		eventsRepo := new(mocks.MockEventsRepo)
		catRepo := new(mocks.MockCategoriesRepo)
		tagsRepo := new(mocks.MockTagsRepo)
		svc := NewEventsService(&ESConfig{
			EventsRepository:     eventsRepo,
			CategoriesRepository: catRepo,
			TagsRepository:       tagsRepo,
		})

		catRepo.On("FindLastIdByIdUser", uint64(1)).Return(uint(3), nil)
		// No existing tag for either the month or the year.
		tagsRepo.On("FindTagIdByTagAndIdCategory", mock.Anything, uint(3)).Return(uint(0), nil)

		eventsRepo.On("CreateEventWithTags",
			mock.MatchedBy(func(tags []model.Tag) bool {
				return len(tags) == 2 &&
					tags[0].Tag == "December" && tags[0].IdCategory == 3 &&
					tags[1].Tag == "1993" && tags[1].IdCategory == 3
			}),
			mock.Anything, mock.Anything, uint64(1),
		).Return(nil)

		err := svc.CreateEvent(1, &model.Event{Date: date}, []uint{})

		assert.NoError(t, err)
		eventsRepo.AssertExpectations(t)
	})

	t.Run("Reuses existing tag ids when the month/year tags already exist", func(t *testing.T) {
		eventsRepo := new(mocks.MockEventsRepo)
		catRepo := new(mocks.MockCategoriesRepo)
		tagsRepo := new(mocks.MockTagsRepo)
		svc := NewEventsService(&ESConfig{
			EventsRepository:     eventsRepo,
			CategoriesRepository: catRepo,
			TagsRepository:       tagsRepo,
		})

		catRepo.On("FindLastIdByIdUser", uint64(1)).Return(uint(3), nil)
		tagsRepo.On("FindTagIdByTagAndIdCategory", mock.Anything, uint(3)).Return(uint(77), nil)

		eventsRepo.On("CreateEventWithTags",
			mock.MatchedBy(func(tags []model.Tag) bool {
				// When a tag already exists, only its id is forwarded.
				return len(tags) == 2 &&
					tags[0].Id == 77 && tags[0].Tag == "" &&
					tags[1].Id == 77 && tags[1].Tag == ""
			}),
			mock.Anything, mock.Anything, uint64(1),
		).Return(nil)

		err := svc.CreateEvent(1, &model.Event{Date: date}, []uint{})

		assert.NoError(t, err)
		eventsRepo.AssertExpectations(t)
	})
}

func TestDeleteEvent(t *testing.T) {
	t.Run("Forwards the id to the repository", func(t *testing.T) {
		eventsRepo := new(mocks.MockEventsRepo)
		svc := NewEventsService(&ESConfig{EventsRepository: eventsRepo})

		eventsRepo.On("Delete", uint(12)).Return(nil)

		err := svc.DeleteEvent(12)

		assert.NoError(t, err)
		eventsRepo.AssertExpectations(t)
	})
}
