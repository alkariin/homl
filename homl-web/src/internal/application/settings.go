package application

import "github.com/alkariin/homl/homl-web/internal/domain/settings"

// SettingsService is the use-case port of the Settings aggregate.
type SettingsService interface {
	GetSettings(idUser uint64) (*settings.SettingsResponse, error)
	UpdateSettings(idUser uint64, s *settings.Settings) (*settings.SettingsResponse, error)
}

type settingsService struct {
	SettingsRepository settings.Repository
}

type SSConfig struct {
	SettingsRepository settings.Repository
}

func NewSettingsService(c *SSConfig) SettingsService {
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
func (s *settingsService) GetSettings(idUser uint64) (*settings.SettingsResponse, error) {
	res, err := s.SettingsRepository.FindByIdUser(idUser)

	response := &settings.SettingsResponse{
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
func (s *settingsService) UpdateSettings(idUser uint64, newSettings *settings.Settings) (*settings.SettingsResponse, error) {
	s.SettingsRepository.Update(newSettings, idUser)

	// Get new settings and send them back
	res, err := s.SettingsRepository.FindByIdUser(idUser)

	response := &settings.SettingsResponse{
		Language:      res.Language,
		DefaultScreen: res.DefaultScreen,
	}

	return response, err
}
