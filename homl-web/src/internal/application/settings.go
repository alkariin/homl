package application

import (
	"context"

	"github.com/alkariin/homl/homl-web/internal/domain/user"
)

// SettingsService holds the settings use cases of the User aggregate.
type SettingsService interface {
	GetSettings(ctx context.Context, idUser uint64) (*user.SettingsResponse, error)
	UpdateSettings(ctx context.Context, idUser uint64, s *user.Settings) (*user.SettingsResponse, error)
}

type settingsService struct {
	UsersRepository user.Repository
}

type SSConfig struct {
	UsersRepository user.Repository
}

func NewSettingsService(c *SSConfig) SettingsService {
	return &settingsService{
		UsersRepository: c.UsersRepository,
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
func (s *settingsService) GetSettings(ctx context.Context, idUser uint64) (*user.SettingsResponse, error) {
	res, err := s.UsersRepository.FindSettingsByIdUser(ctx, idUser)
	if err != nil {
		return nil, err
	}

	response := &user.SettingsResponse{
		Language:      res.Language,
		DefaultScreen: res.DefaultScreen,
	}

	return response, nil
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
func (s *settingsService) UpdateSettings(ctx context.Context, idUser uint64, newSettings *user.Settings) (*user.SettingsResponse, error) {
	err := s.UsersRepository.UpdateSettings(ctx, newSettings, idUser)
	if err != nil {
		return nil, err
	}

	// Get new settings and send them back
	res, err := s.UsersRepository.FindSettingsByIdUser(ctx, idUser)
	if err != nil {
		return nil, err
	}

	response := &user.SettingsResponse{
		Language:      res.Language,
		DefaultScreen: res.DefaultScreen,
	}

	return response, nil
}
