package mocks

import (
	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/stretchr/testify/mock"
)

// MockEventsRepo is a programmable testify mock for domain.EventsRepository.
type MockEventsRepo struct {
	mock.Mock
}

func (m *MockEventsRepo) FindEventsWithTags(encTags []string, idUser uint64) (map[uint]domain.Event, map[uint][]domain.Tag, error) {
	ret := m.Called(encTags, idUser)

	var r0 map[uint]domain.Event
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(map[uint]domain.Event)
	}

	var r1 map[uint][]domain.Tag
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(map[uint][]domain.Tag)
	}

	var r2 error
	if ret.Get(2) != nil {
		r2 = ret.Get(2).(error)
	}

	return r0, r1, r2
}

func (m *MockEventsRepo) CreateEventWithTags(tags []domain.Tag, tagsId []uint, event *domain.Event, idUser uint64) error {
	ret := m.Called(tags, tagsId, event, idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockEventsRepo) UpdateEventWithTags(tags []domain.Tag, tagsId []uint, event *domain.Event, idUser uint64) error {
	ret := m.Called(tags, tagsId, event, idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockEventsRepo) Delete(id uint) error {
	ret := m.Called(id)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}
