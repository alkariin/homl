package settings

import (
	"testing"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/mocks"
	"github.com/stretchr/testify/assert"
)

func TestGetSettings(t *testing.T) {

	t.Run("Get settings with good input", func(t *testing.T) {
		// idUser, _ := uuid.NewRandom()
		idUser := uint64(1)

		expectedSettingsResponse := &domain.SettingsResponse{
			Language:      "de",
			DefaultScreen: true,
		}

		expectedSettings := &domain.Settings{
			Language:      "de",
			DefaultScreen: true,
		}

		mockSettingsRepo := new(mocks.MockSettingsRepo)
		settingsService := NewSettingsService(&SSConfig{
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
	settingsService := NewSettingsService(&SSConfig{
		SettingsRepository: mockSettingsRepo,
	})

	t.Run("Update settings with good inputs", func(t *testing.T) {
		settings := &domain.Settings{
			Language:      "de",
			DefaultScreen: true,
		}

		expectedSettings := &domain.SettingsResponse{
			Language:      "de",
			DefaultScreen: true,
		}

		mockSettingsRepo.On("Update", settings, idUser).Return(nil)
		mockSettingsRepo.On("FindByIdUser", idUser).Return(settings, nil)

		resultSettings, err := settingsService.UpdateSettings(idUser, settings)

		assert.NoError(t, err)
		assert.Equal(t, resultSettings, expectedSettings)
		mockSettingsRepo.AssertExpectations(t)
	})
}
