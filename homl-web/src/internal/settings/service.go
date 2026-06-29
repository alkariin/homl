package settings

import (
	"github.com/alkariin/homl/homl-web/internal/domain"
)

type settingsService struct {
	SettingsRepository domain.SettingsRepository
}

type SSConfig struct {
	SettingsRepository domain.SettingsRepository
}

func NewSettingsService(c *SSConfig) domain.SettingsService {
	return &settingsService{
		SettingsRepository: c.SettingsRepository,
	}
}

/** response:
 * {
 *   language: string,
 *   defaultScreen: bool,
 *   isFingerprintEnabled: bool,
 *   isPinEnabled: bool
 * }
 */
func (s *settingsService) GetSettings(idUser uint64) (*domain.SettingsResponse, error) {
	res, err := s.SettingsRepository.FindByIdUser(idUser)

	response := &domain.SettingsResponse{
		Language:      res.Language,
		DefaultScreen: res.DefaultScreen,
	}

	return response, err
}

/** input:
 * {
 *	 language: string,
 *   defaultScreen: bool,
 *   isFingerprintEnabled: bool,
 *   isPinEnabled: bool,
 *   pin?: string,
 *   pkey?: string
 * }
 */
func (s *settingsService) UpdateSettings(idUser uint64, settings *domain.Settings) (*domain.SettingsResponse, error) {
	s.SettingsRepository.Update(settings, idUser)

	// Get new settings and send them back
	res, err := s.SettingsRepository.FindByIdUser(idUser)

	response := &domain.SettingsResponse{
		Language:      res.Language,
		DefaultScreen: res.DefaultScreen,
	}

	return response, err
}
