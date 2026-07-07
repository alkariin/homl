package mocks

import (
	"time"

	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/stretchr/testify/mock"
)

// MockUsersRepo is a programmable testify mock for user.Repository.
type MockUsersRepo struct {
	mock.Mock
}

func (m *MockUsersRepo) Registration(u *user.User, language *user.Language) error {
	ret := m.Called(u, language)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockUsersRepo) FindById(idUser uint64) (*user.User, error) {
	res := m.Called(idUser)

	var r0 *user.User
	if res.Get(0) != nil {
		r0 = res.Get(0).(*user.User)
	}

	var r1 error
	if res.Get(1) != nil {
		r1 = res.Get(1).(error)
	}

	return r0, r1
}

func (m *MockUsersRepo) FindByUsername(username string) (*user.User, error) {
	ret := m.Called(username)

	var r0 *user.User
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*user.User)
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

func (m *MockUsersRepo) FindPkeyAndChallengeById(idUser uint64) (*user.User, error) {
	ret := m.Called(idUser)

	var r0 *user.User
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*user.User)
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

func (m *MockUsersRepo) UpdatePinAndFingerprint(s *user.User, removePkey bool, removePin bool) error {
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

func (m *MockUsersRepo) CreateAuth(userid uint64, td *user.TokenDetails) error {
	ret := m.Called(userid, td)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockUsersRepo) FetchAuth(authD *user.AccessDetails) (uint64, error) {
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

func (m *MockUsersRepo) FindSettingsByIdUser(idUser uint64) (*user.Settings, error) {
	res := m.Called(idUser)

	var r0 *user.Settings
	if res.Get(0) != nil {
		r0 = res.Get(0).(*user.Settings)
	}

	var r1 error
	if res.Get(1) != nil {
		r1 = res.Get(1).(error)
	}

	return r0, r1
}

func (m *MockUsersRepo) UpdateSettings(s *user.Settings, idUser uint64) error {
	ret := m.Called(s, idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockUsersRepo) StoreResetToken(userId uint64, token string, ttl time.Duration) error {
	ret := m.Called(userId, token, ttl)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockUsersRepo) ConsumeResetToken(token string) (uint64, error) {
	ret := m.Called(token)

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return ret.Get(0).(uint64), r1
}
