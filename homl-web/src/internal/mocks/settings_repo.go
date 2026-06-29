package mocks

import (
	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/stretchr/testify/mock"
)

type MockSettingsRepo struct {
	mock.Mock
}

func (m *MockSettingsRepo) FindByIdUser(idUser uint64) (*domain.Settings, error) {
	res := m.Called(idUser)

	var r0 *domain.Settings
	if res.Get(0) != nil {
		r0 = res.Get(0).(*domain.Settings)
	}

	var r1 error

	if res.Get(1) != nil {
		r1 = res.Get(1).(error)
	}

	return r0, r1
}

func (m *MockSettingsRepo) Update(s *domain.Settings, idUser uint64) error {
	ret := m.Called(s, idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}
