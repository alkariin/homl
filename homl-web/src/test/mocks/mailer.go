package mocks

import (
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/stretchr/testify/mock"
)

// MockMailer is a programmable testify mock for application.Mailer.
type MockMailer struct {
	mock.Mock
}

func (m *MockMailer) SendPasswordResetCode(to string, code string, language user.Language) error {
	ret := m.Called(to, code, language)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}
