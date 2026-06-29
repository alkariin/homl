package settings

import (
	"database/sql"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/shared"
)

type SettingsRepository struct {
	DB *sql.DB
}

func NewSettingsRepository(db *sql.DB) domain.SettingsRepository {
	return &SettingsRepository{
		DB: db,
	}
}

func (r *SettingsRepository) FindByIdUser(idUser uint64) (*domain.Settings, error) {
	settings := domain.Settings{}
	row := r.DB.QueryRow("SELECT language, defaultScreen FROM Users WHERE id = ?;", idUser)
	err := row.Scan(&settings.Language, &settings.DefaultScreen)
	if err != nil {
		return nil, err
	}
	return &settings, nil
}

func (r *SettingsRepository) Update(s *domain.Settings, idUser uint64) error {
	res, err := r.DB.Exec("UPDATE Users SET language = ?, defaultScreen = ? WHERE idUser = ?", s.Language, s.DefaultScreen, idUser)
	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return shared.NewInternal()
	}

	return nil
}
