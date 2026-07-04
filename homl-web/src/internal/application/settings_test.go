package application_test

import (
	"testing"

	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/alkariin/homl/homl-web/test/mocks"
	"github.com/stretchr/testify/assert"
)

func TestGetSettings(t *testing.T) {

	t.Run("Get settings with good input", func(t *testing.T) {
		// idUser, _ := uuid.NewRandom()
		idUser := uint64(1)

		expectedSettingsResponse := &user.SettingsResponse{
			Language:      "de",
			DefaultScreen: true,
		}

		expectedSettings := &user.Settings{
			Language:      "de",
			DefaultScreen: true,
		}

		mockUsersRepo := new(mocks.MockUsersRepo)
		settingsService := application.NewSettingsService(&application.SSConfig{
			UsersRepository: mockUsersRepo,
		})
		mockUsersRepo.On("FindSettingsByIdUser", idUser).Return(expectedSettings, nil)

		resultSettings, err := settingsService.GetSettings(idUser)
		assert.NoError(t, err)
		assert.Equal(t, resultSettings, expectedSettingsResponse)
		mockUsersRepo.AssertExpectations(t)
	})
}

func TestUpdateSettings(t *testing.T) {
	idUser := uint64(1)

	mockUsersRepo := new(mocks.MockUsersRepo)
	settingsService := application.NewSettingsService(&application.SSConfig{
		UsersRepository: mockUsersRepo,
	})

	t.Run("Update settings with good inputs", func(t *testing.T) {
		newSettings := &user.Settings{
			Language:      "de",
			DefaultScreen: true,
		}

		expectedSettings := &user.SettingsResponse{
			Language:      "de",
			DefaultScreen: true,
		}

		mockUsersRepo.On("UpdateSettings", newSettings, idUser).Return(nil)
		mockUsersRepo.On("FindSettingsByIdUser", idUser).Return(newSettings, nil)

		resultSettings, err := settingsService.UpdateSettings(idUser, newSettings)

		assert.NoError(t, err)
		assert.Equal(t, resultSettings, expectedSettings)
		mockUsersRepo.AssertExpectations(t)
	})
}
