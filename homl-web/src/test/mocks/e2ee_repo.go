package mocks

import (
	"context"

	"github.com/alkariin/homl/homl-web/internal/domain/e2ee"
	"github.com/stretchr/testify/mock"
)

// MockE2EERepo is a programmable testify mock for e2ee.Repository.
// The ctx argument is deliberately not forwarded to m.Called so expectations
// stay expressed on the business arguments only.
type MockE2EERepo struct {
	mock.Mock
}

func (m *MockE2EERepo) IsEnabled(ctx context.Context, idUser uint64) (bool, error) {
	ret := m.Called(idUser)

	var r0 bool
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(bool)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}

func (m *MockE2EERepo) Migrate(ctx context.Context, idUser uint64, enable bool, keyCheck *string, data *e2ee.MigrationData) error {
	ret := m.Called(idUser, enable, keyCheck, data)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockE2EERepo) Purge(ctx context.Context, idUser uint64) error {
	ret := m.Called(idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}
