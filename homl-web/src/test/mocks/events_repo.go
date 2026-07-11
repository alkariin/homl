package mocks

import (
	"context"

	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
	"github.com/stretchr/testify/mock"
)

// MockEventsRepo is a programmable testify mock for event.Repository.
// The ctx argument is deliberately not forwarded to m.Called so expectations
// stay expressed on the business arguments only.
type MockEventsRepo struct {
	mock.Mock
}

func (m *MockEventsRepo) FindEventsWithTags(ctx context.Context, encTags []string, idUser uint64) (map[uint]event.Event, map[uint][]category.Tag, error) {
	ret := m.Called(encTags, idUser)

	var r0 map[uint]event.Event
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(map[uint]event.Event)
	}

	var r1 map[uint][]category.Tag
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(map[uint][]category.Tag)
	}

	var r2 error
	if ret.Get(2) != nil {
		r2 = ret.Get(2).(error)
	}

	return r0, r1, r2
}

func (m *MockEventsRepo) CreateEventWithTags(ctx context.Context, tags []category.Tag, tagsId []uint, event *event.Event, idUser uint64) error {
	ret := m.Called(tags, tagsId, event, idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockEventsRepo) UpdateEventWithTags(ctx context.Context, tags []category.Tag, tagsId []uint, event *event.Event, idUser uint64) error {
	ret := m.Called(tags, tagsId, event, idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockEventsRepo) Delete(ctx context.Context, id uint, idUser uint64) error {
	ret := m.Called(id, idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}
