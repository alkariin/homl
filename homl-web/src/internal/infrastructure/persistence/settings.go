package persistence

import (
	"github.com/alkariin/homl/homl-web/internal/domain/user"
)

// Settings belong to the User aggregate, so their persistence operations are
// methods of UsersRepository.

func (u *UsersRepository) FindSettingsByIdUser(idUser uint64) (*user.Settings, error) {
	settings := user.Settings{}
	row := u.DB.QueryRow("SELECT language, defaultScreen FROM Users WHERE id = ?;", idUser)
	err := row.Scan(&settings.Language, &settings.DefaultScreen)
	if err != nil {
		return nil, err
	}
	return &settings, nil
}

func (u *UsersRepository) UpdateSettings(s *user.Settings, idUser uint64) error {
	// Tolerate a no-op update (same values) since this driver's RowsAffected
	// reports changed rows, not matched rows.
	_, err := u.DB.Exec("UPDATE Users SET language = ?, defaultScreen = ? WHERE id = ?", s.Language, s.DefaultScreen, idUser)
	return err
}
