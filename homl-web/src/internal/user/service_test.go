package user

import (
	"testing"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/mocks"
	"github.com/stretchr/testify/assert"
)

func TestSecureAuth(t *testing.T) {

	pkey := "asfdslfjls"
	pin := "0000"

	mockUsersRepo := new(mocks.MockUsersRepo)
	usersService := NewUsersService(&UserConfig{
		UsersRepository: mockUsersRepo,
	})

	t.Run("Update user with good inputs", func(t *testing.T) {
		user := &domain.User{
			ID:                   1,
			IsFingerprintEnabled: true,
			Pkey:                 nil,
			Pin:                  nil,
			IsPinEnabled:         false,
		}

		userResponse := &domain.UserResponse{
			IsFingerprintEnabled: true,
			IsPinEnabled:         false,
		}

		removePkey := !user.IsFingerprintEnabled && !user.IsPinEnabled
		removePin := !user.IsPinEnabled

		mockUsersRepo.On("UpdatePinAndFingerprint", user, removePkey, removePin).Return(nil)
		mockUsersRepo.On("FindById", user.ID).Return(user, nil)

		resultUser, err := usersService.SecureAuth(user)

		assert.NoError(t, err)
		assert.Equal(t, resultUser, userResponse)
		mockUsersRepo.AssertExpectations(t)
	})

	t.Run("Check that fingerprint and pin can't be both activated", func(t *testing.T) {
		user := &domain.User{
			ID:                   1,
			IsFingerprintEnabled: true,
			IsPinEnabled:         true,
		}

		resultUser, err := usersService.SecureAuth(user)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})

	t.Run("Check that pin should not be provided if fingerprint is enabled", func(t *testing.T) {
		user := &domain.User{
			ID:                   1,
			IsFingerprintEnabled: true,
			Pin:                  &pin,
		}

		resultUser, err := usersService.SecureAuth(user)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})

	t.Run("Check that pin should not be provided if pin feature is disabled", func(t *testing.T) {
		user := &domain.User{
			ID:           1,
			IsPinEnabled: false,
			Pin:          &pin,
		}

		resultUser, err := usersService.SecureAuth(user)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})

	t.Run("Check that pKey must be here if pin is given", func(t *testing.T) {
		user := &domain.User{
			ID:           1,
			IsPinEnabled: true,
			Pin:          &pin,
		}

		resultUser, err := usersService.SecureAuth(user)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})

	t.Run("Check that pKey must be nil if both fingerprint and pin are disabled", func(t *testing.T) {
		user := &domain.User{
			ID:                   1,
			IsFingerprintEnabled: false,
			IsPinEnabled:         false,
			Pkey:                 &pkey,
		}

		resultUser, err := usersService.SecureAuth(user)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})
}
