package mocks

import (
	"github.com/alkariin/homl/homl-web/model"
	"github.com/stretchr/testify/mock"
)

// MockUsersRepo is a programmable testify mock for model.UsersRepository.
type MockUsersRepo struct {
	mock.Mock
}

func (m *MockUsersRepo) Registration(user *model.User, language *model.Language) (map[string]string, error) {
	ret := m.Called(user, language)

	var r0 map[string]string
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(map[string]string)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}

func (m *MockUsersRepo) FindById(idUser uint64) (*model.User, error) {
	res := m.Called(idUser)

	var r0 *model.User
	if res.Get(0) != nil {
		r0 = res.Get(0).(*model.User)
	}

	var r1 error
	if res.Get(1) != nil {
		r1 = res.Get(1).(error)
	}

	return r0, r1
}

func (m *MockUsersRepo) FindByUsername(username string) (*model.User, error) {
	ret := m.Called(username)

	var r0 *model.User
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*model.User)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}

func (m *MockUsersRepo) FindIdByUsername(username string) (uint64, error) {
	ret := m.Called(username)

	var r0 uint64
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(uint64)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}

func (m *MockUsersRepo) FindPkeyAndChallengeById(idUser uint64) (*model.User, error) {
	ret := m.Called(idUser)

	var r0 *model.User
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*model.User)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}

func (m *MockUsersRepo) UpdatePassword(idUser uint64, hashedPassword string) error {
	ret := m.Called(idUser, hashedPassword)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockUsersRepo) FindPasswordById(idUser uint64) (*string, error) {
	ret := m.Called(idUser)

	var r0 *string
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*string)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}

func (m *MockUsersRepo) UpdateChallenge(idUser uint64, challenge *string) error {
	ret := m.Called(idUser, challenge)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockUsersRepo) ResetPinCounter(idUser uint64) error {
	ret := m.Called(idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockUsersRepo) CheckPin(idUser uint64, pin string) error {
	ret := m.Called(idUser, pin)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockUsersRepo) UpdatePinAndFingerprint(s *model.User, removePkey bool, removePin bool) error {
	ret := m.Called(s, removePkey, removePin)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockUsersRepo) DeleteAuth(givenUuid string) (int64, error) {
	ret := m.Called(givenUuid)

	var r0 int64
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(int64)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}

func (m *MockUsersRepo) CreateAuth(userid uint64, td *model.TokenDetails) error {
	ret := m.Called(userid, td)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockUsersRepo) FetchAuth(authD *model.AccessDetails) (uint64, error) {
	ret := m.Called(authD)

	var r0 uint64
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(uint64)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}
