package user

import (
	"testing"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/mocks"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"golang.org/x/crypto/bcrypt"
)

func TestLogin(t *testing.T) {
	const password = "Demo1234!"
	hashed, _ := bcrypt.GenerateFromPassword([]byte(password), 8)

	t.Run("Returns an access/refresh token pair on valid credentials", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := NewUsersService(&UserConfig{UsersRepository: mockRepo})

		stored := &domain.User{ID: 1, Username: "demo@homl.local", Password: string(hashed)}
		mockRepo.On("FindByUsername", "demo@homl.local").Return(stored, nil)
		mockRepo.On("CreateAuth", uint64(1), mock.AnythingOfType("*domain.TokenDetails")).Return(nil)

		tokens, err := svc.Login(&domain.User{Username: "demo@homl.local", Password: password})

		assert.NoError(t, err)
		assert.NotEmpty(t, tokens["access_token"])
		assert.NotEmpty(t, tokens["refresh_token"])
		mockRepo.AssertExpectations(t)
	})

	t.Run("Rejects a wrong password without issuing tokens", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := NewUsersService(&UserConfig{UsersRepository: mockRepo})

		stored := &domain.User{ID: 1, Username: "demo@homl.local", Password: string(hashed)}
		mockRepo.On("FindByUsername", "demo@homl.local").Return(stored, nil)

		tokens, err := svc.Login(&domain.User{Username: "demo@homl.local", Password: "wrong-password"})

		assert.Error(t, err)
		assert.Nil(t, tokens)
		mockRepo.AssertNotCalled(t, "CreateAuth")
	})

	t.Run("Rejects an unknown user", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := NewUsersService(&UserConfig{UsersRepository: mockRepo})

		mockRepo.On("FindByUsername", "ghost@homl.local").Return(nil, assert.AnError)

		tokens, err := svc.Login(&domain.User{Username: "ghost@homl.local", Password: password})

		assert.Error(t, err)
		assert.Nil(t, tokens)
	})
}

func TestLogout(t *testing.T) {
	t.Run("Clears the challenge and deletes the auth entry", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := NewUsersService(&UserConfig{UsersRepository: mockRepo})

		ad := &domain.AccessDetails{AccessUuid: "uuid-1", UserId: 1}
		mockRepo.On("UpdateChallenge", uint64(1), (*string)(nil)).Return(nil)
		mockRepo.On("DeleteAuth", "uuid-1").Return(int64(1), nil)

		err := svc.Logout(ad)

		assert.NoError(t, err)
		mockRepo.AssertExpectations(t)
	})

	t.Run("Errors when no auth entry was deleted", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := NewUsersService(&UserConfig{UsersRepository: mockRepo})

		ad := &domain.AccessDetails{AccessUuid: "uuid-missing", UserId: 1}
		mockRepo.On("UpdateChallenge", uint64(1), (*string)(nil)).Return(nil)
		mockRepo.On("DeleteAuth", "uuid-missing").Return(int64(0), nil)

		err := svc.Logout(ad)

		assert.Error(t, err)
		mockRepo.AssertExpectations(t)
	})
}
