package service

import (
	"github.com/alkariin/homl/homl-web/model"
)

type settingsService struct {
	SettingsRepository model.SettingsRepository
}

type SSConfig struct {
	SettingsRepository model.SettingsRepository
}

func NewSettingsService(c *SSConfig) model.SettingsService {
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
func (s *settingsService) GetSettings(idUser uint64) (*model.SettingsResponse, error) {
	res, err := s.SettingsRepository.FindByIdUser(idUser)

	response := &model.SettingsResponse{
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
func (s *settingsService) UpdateSettings(idUser uint64, settings *model.Settings) (*model.SettingsResponse, error) {
	s.SettingsRepository.Update(settings, idUser)

	// Get new settings and send them back
	res, err := s.SettingsRepository.FindByIdUser(idUser)

	response := &model.SettingsResponse{
		Language:      res.Language,
		DefaultScreen: res.DefaultScreen,
	}

	return response, err
}
