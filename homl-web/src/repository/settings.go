package repository

import (
	"database/sql"

	"github.com/alkariin/homl/homl-web/helper"
	"github.com/alkariin/homl/homl-web/model"
)

type SettingsRepository struct {
	DB *sql.DB
}

func NewSettingsRepository(db *sql.DB) model.SettingsRepository {
	return &SettingsRepository{
		DB: db,
	}
}

func (r *SettingsRepository) FindByIdUser(idUser uint64) (*model.Settings, error) {
	settings := model.Settings{}
	row := r.DB.QueryRow("SELECT language, defaultScreen FROM Users WHERE id = ?;", idUser)
	err := row.Scan(&settings.Language, &settings.DefaultScreen)
	if err != nil {
		return nil, err
	}
	return &settings, nil
}

func (r *SettingsRepository) Update(s *model.Settings, idUser uint64) error {
	res, err := r.DB.Exec("UPDATE Users SET language = ?, defaultScreen = ? WHERE idUser = ?", s.Language, s.DefaultScreen, idUser)
	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return helper.NewInternal()
	}

	return nil
}
