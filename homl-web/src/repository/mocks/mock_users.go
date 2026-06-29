package mocks

import (
	"github.com/alkariin/homl/homl-web/model"
	"github.com/stretchr/testify/mock"
)

type MockUsersRepo struct {
	mock.Mock
}

func (m *MockUsersRepo) Registration(user *model.User, language *model.Language) (map[string]string, error) {
	return nil, nil
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
	return &model.User{}, nil
}
func (m *MockUsersRepo) FindIdByUsername(username string) (uint64, error) { return 0, nil }
func (m *MockUsersRepo) FindPkeyAndChallengeById(idUser uint64) (*model.User, error) {
	return &model.User{}, nil
}
func (m *MockUsersRepo) UpdatePassword(idUser uint64, hashedPassword string) error { return nil }
func (m *MockUsersRepo) FindPasswordById(idUser uint64) (*string, error)           { return nil, nil }
func (m *MockUsersRepo) UpdateChallenge(idUser uint64, challenge *string) error    { return nil }
func (m *MockUsersRepo) ResetPinCounter(idUser uint64) error                       { return nil }
func (m *MockUsersRepo) CheckPin(idUser uint64, pin string) error                  { return nil }

func (m *MockUsersRepo) UpdatePinAndFingerprint(s *model.User, removePkey bool, removePin bool) error {
	ret := m.Called(s, removePkey, removePin)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockUsersRepo) DeleteAuth(givenUuid string) (int64, error)             { return 0, nil }
func (m *MockUsersRepo) CreateAuth(userid uint64, td *model.TokenDetails) error { return nil }
func (m *MockUsersRepo) FetchAuth(authD *model.AccessDetails) (uint64, error)   { return 0, nil }
