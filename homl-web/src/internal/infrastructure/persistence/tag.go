package persistence

import (
	"context"
	"database/sql"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/crypto"
	"github.com/alkariin/homl/homl-web/internal/domain/tag"
)

type TagsRepository struct {
	DB *sql.DB
}

func NewTagsRepository(db *sql.DB) tag.Repository {
	return &TagsRepository{
		DB: db,
	}
}

func (t *TagsRepository) Create(tagNameEncrypt string, idCategory uint) error {
	_, err := t.DB.Query("INSERT INTO Tags (tag, idCategory) VALUES (?, ?)", tagNameEncrypt, idCategory)
	return err
}

func (t *TagsRepository) Update(tagNameEncrypt string, idCategory uint, idTag uint) error {
	res, err := t.DB.Exec("UPDATE Tags SET tag = ?, idCategory = ? WHERE id = ?", tagNameEncrypt, idCategory, idTag)

	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	return err
}

func (t *TagsRepository) Delete(idTag uint, idUser uint64) error {
	res, err := t.DB.Exec(`
		DELETE t FROM Tags t
		INNER JOIN Categories
		ON t.idCategory = Categories.id
		WHERE t.id = ?
		AND idUser = ?
		AND idPerson IS NULL
	`, idTag, idUser)
	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	return nil
}

func (t *TagsRepository) FindTagIdByTagAndIdCategory(tag string, idCategoryDate uint) (uint, error) {
	var idTag uint
	row := t.DB.QueryRow("SELECT COALESCE(MIN(id), 0) FROM Tags WHERE tag = ? AND idCategory = ?;", tag, idCategoryDate)
	err := row.Scan(&idTag)
	if err != nil {
		return 0, err
	}

	return idTag, nil
}

func (t *TagsRepository) FindMainTagIdOfPerson(idPerson uint) (uint, error) {
	var mainPersonTagId uint
	row := t.DB.QueryRow("SELECT MIN(id) AS idTag FROM Tags WHERE idPerson=?", idPerson)
	err := row.Scan(&mainPersonTagId)
	if err != nil {
		return 0, err
	}
	return mainPersonTagId, nil
}

func CreateAllTags(ctx context.Context, tx *sql.Tx, tags []tag.Tag) ([]uint, error) {
	// Create date tags if needed
	var tagsId = []uint{}
	for _, tag := range tags {
		if tag.Id == 0 {
			encTag, err := crypto.Encrypt(tag.Tag)
			if err != nil {
				tx.Rollback()
				return nil, err
			}

			_, err = tx.ExecContext(ctx, "INSERT INTO Tags (tag, idCategory) VALUES (?, ?)", encTag, tag.IdCategory)
			// Refused if the tag already exists in another category
			if err != nil {
				tx.Rollback()
				return nil, err
			}

			row := tx.QueryRow("SELECT LAST_INSERT_ID();")
			err = row.Scan(&tag.Id)
			if err != nil {
				tx.Rollback()
				return nil, err
			}
		}

		tagsId = append(tagsId, tag.Id)
	}

	return tagsId, nil
}
