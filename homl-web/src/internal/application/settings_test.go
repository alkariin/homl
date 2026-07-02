package application_test

import (
	"testing"

	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/settings"
	"github.com/alkariin/homl/homl-web/test/mocks"
	"github.com/stretchr/testify/assert"
)

func TestGetSettings(t *testing.T) {

	t.Run("Get settings with good input", func(t *testing.T) {
		// idUser, _ := uuid.NewRandom()
		idUser := uint64(1)

		expectedSettingsResponse := &settings.SettingsResponse{
			Language:      "de",
			DefaultScreen: true,
		}

		expectedSettings := &settings.Settings{
			Language:      "de",
			DefaultScreen: true,
		}

		mockSettingsRepo := new(mocks.MockSettingsRepo)
		settingsService := application.NewSettingsService(&application.SSConfig{
			SettingsRepository: mockSettingsRepo,
		})
		mockSettingsRepo.On("FindByIdUser", idUser).Return(expectedSettings, nil)

		resultSettings, err := settingsService.GetSettings(idUser)
		assert.NoError(t, err)
		assert.Equal(t, resultSettings, expectedSettingsResponse)
		mockSettingsRepo.AssertExpectations(t)
	})
}

func TestUpdateSettings(t *testing.T) {
	idUser := uint64(1)

	mockSettingsRepo := new(mocks.MockSettingsRepo)
	settingsService := application.NewSettingsService(&application.SSConfig{
		SettingsRepository: mockSettingsRepo,
	})

	t.Run("Update settings with good inputs", func(t *testing.T) {
		newSettings := &settings.Settings{
			Language:      "de",
			DefaultScreen: true,
		}

		expectedSettings := &settings.SettingsResponse{
			Language:      "de",
			DefaultScreen: true,
		}

		mockSettingsRepo.On("Update", newSettings, idUser).Return(nil)
		mockSettingsRepo.On("FindByIdUser", idUser).Return(newSettings, nil)

		resultSettings, err := settingsService.UpdateSettings(idUser, newSettings)

		assert.NoError(t, err)
		assert.Equal(t, resultSettings, expectedSettings)
		mockSettingsRepo.AssertExpectations(t)
	})
}
