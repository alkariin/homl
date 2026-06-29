package mocks

import (
	"github.com/alkariin/homl/homl-web/model"
	"github.com/stretchr/testify/mock"
)

// MockEventsRepo is a programmable testify mock for model.EventsRepository.
type MockEventsRepo struct {
	mock.Mock
}

func (m *MockEventsRepo) FindEventsWithTags(encTags []string, idUser uint64) (map[uint]model.Event, map[uint][]model.Tag, error) {
	ret := m.Called(encTags, idUser)

	var r0 map[uint]model.Event
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(map[uint]model.Event)
	}

	var r1 map[uint][]model.Tag
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(map[uint][]model.Tag)
	}

	var r2 error
	if ret.Get(2) != nil {
		r2 = ret.Get(2).(error)
	}

	return r0, r1, r2
}

func (m *MockEventsRepo) CreateEventWithTags(tags []model.Tag, tagsId []uint, event *model.Event, idUser uint64) error {
	ret := m.Called(tags, tagsId, event, idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockEventsRepo) UpdateEventWithTags(tags []model.Tag, tagsId []uint, event *model.Event, idUser uint64) error {
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
