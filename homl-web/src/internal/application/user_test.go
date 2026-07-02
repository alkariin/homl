package application_test

import (
	"testing"

	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/alkariin/homl/homl-web/test/mocks"
	"github.com/stretchr/testify/assert"
)

func TestSecureAuth(t *testing.T) {

	pkey := "asfdslfjls"
	pin := "0000"

	mockUsersRepo := new(mocks.MockUsersRepo)
	usersService := application.NewUsersService(&application.UserConfig{
		UsersRepository: mockUsersRepo,
	})

	t.Run("Update u with good inputs", func(t *testing.T) {
		u := &user.User{
			ID:                   1,
			IsFingerprintEnabled: true,
			Pkey:                 nil,
			Pin:                  nil,
			IsPinEnabled:         false,
		}

		userResponse := &user.UserResponse{
			IsFingerprintEnabled: true,
			IsPinEnabled:         false,
		}

		removePkey := !u.IsFingerprintEnabled && !u.IsPinEnabled
		removePin := !u.IsPinEnabled

		mockUsersRepo.On("UpdatePinAndFingerprint", u, removePkey, removePin).Return(nil)
		mockUsersRepo.On("FindById", u.ID).Return(u, nil)

		resultUser, err := usersService.SecureAuth(u)

		assert.NoError(t, err)
		assert.Equal(t, resultUser, userResponse)
		mockUsersRepo.AssertExpectations(t)
	})

	t.Run("Check that fingerprint and pin can't be both activated", func(t *testing.T) {
		u := &user.User{
			ID:                   1,
			IsFingerprintEnabled: true,
			IsPinEnabled:         true,
		}

		resultUser, err := usersService.SecureAuth(u)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})

	t.Run("Check that pin should not be provided if fingerprint is enabled", func(t *testing.T) {
		u := &user.User{
			ID:                   1,
			IsFingerprintEnabled: true,
			Pin:                  &pin,
		}

		resultUser, err := usersService.SecureAuth(u)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})

	t.Run("Check that pin should not be provided if pin feature is disabled", func(t *testing.T) {
		u := &user.User{
			ID:           1,
			IsPinEnabled: false,
			Pin:          &pin,
		}

		resultUser, err := usersService.SecureAuth(u)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})

	t.Run("Check that pKey must be here if pin is given", func(t *testing.T) {
		u := &user.User{
			ID:           1,
			IsPinEnabled: true,
			Pin:          &pin,
		}

		resultUser, err := usersService.SecureAuth(u)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})

	t.Run("Check that pKey must be nil if both fingerprint and pin are disabled", func(t *testing.T) {
		u := &user.User{
			ID:                   1,
			IsFingerprintEnabled: false,
			IsPinEnabled:         false,
			Pkey:                 &pkey,
		}

		resultUser, err := usersService.SecureAuth(u)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})
}
