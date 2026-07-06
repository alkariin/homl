package persistence

import (
	"context"

	"github.com/alkariin/homl/homl-web/internal/domain/user"
)

// Settings belong to the User aggregate, so their persistence operations are
// methods of UsersRepository.

func (u *UsersRepository) FindSettingsByIdUser(ctx context.Context, idUser uint64) (*user.Settings, error) {
	settings := user.Settings{}
	err := u.DB.GetContext(ctx, &settings, "SELECT language, defaultScreen FROM Users WHERE id = ?;", idUser)
	if err != nil {
		return nil, err
	}
	return &settings, nil
}

func (u *UsersRepository) UpdateSettings(ctx context.Context, s *user.Settings, idUser uint64) error {
	// Tolerate a no-op update (same values) since this driver's RowsAffected
	// reports changed rows, not matched rows.
	_, err := u.DB.ExecContext(ctx, "UPDATE Users SET language = ?, defaultScreen = ? WHERE id = ?", s.Language, s.DefaultScreen, idUser)
	return err
}
