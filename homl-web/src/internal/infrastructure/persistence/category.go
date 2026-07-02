package persistence

import (
	"context"
	"database/sql"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/crypto"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/tag"
)

type CategoriesRepository struct {
	DB *sql.DB
}

func NewCategoriesRepository(db *sql.DB) category.Repository {
	return &CategoriesRepository{
		DB: db,
	}
}

func (c *CategoriesRepository) FindById(id uint) (*category.Category, error) {
	var storedCategory category.Category
	row := c.DB.QueryRow("SELECT category, color, isLocked FROM Categories WHERE id = ?", id)
	err := row.Scan(&storedCategory.Category, &storedCategory.Color, &storedCategory.IsLocked)
	if err != nil {
		return nil, err
	}
	return &storedCategory, nil
}

func (c *CategoriesRepository) FindLastIdByIdUser(idUser uint64) (uint, error) {
	var idCategoryDate uint
	row := c.DB.QueryRow("SELECT id FROM Categories WHERE idUser = ? LIMIT 1;", idUser) // the date category must be the first one
	err := row.Scan(&idCategoryDate)
	if err != nil {
		return 0, err
	}
	return idCategoryDate, nil
}

func (c *CategoriesRepository) CheckLastIdByIdAndIdUser(idUser uint64, idCategory uint) error {
	var resId uint
	row := c.DB.QueryRow("SELECT id FROM Categories WHERE id = ? AND idUser = ? LIMIT 1;", idCategory, idUser)
	err := row.Scan(&resId)
	if err != nil {
		return err
	}
	return nil
}

// Returns all categories with all tags, but without the tags of the category persons
func (c *CategoriesRepository) GetAllCategoriesWithTags(idUser uint64) (map[uint]category.Category, map[uint][]tag.TagDTO, error) {
	type SQLTag struct {
		Id  sql.NullInt64  `json:"id"`
		Tag sql.NullString `json:"tag"`
	}

	results, err := c.DB.Query(`
		SELECT Categories.Id, category, color, isLocked, Tags.id, tag
		FROM Categories
		LEFT JOIN Tags
		ON Categories.id = Tags.idCategory
		WHERE idUser = ?
		ORDER BY Categories.id, Tags.id
	`, idUser)

	if err != nil {
		return nil, nil, err
	}

	var tags = make(map[uint][]tag.TagDTO)
	var categories = make(map[uint]category.Category)
	for results.Next() {
		var sqlTag SQLTag
		var t tag.TagDTO
		var cat category.Category
		err = results.Scan(&cat.Id, &cat.Category, &cat.Color, &cat.IsLocked, &sqlTag.Id, &sqlTag.Tag)
		// if the category is empty, Tag will be null
		if sqlTag.Id.Valid && sqlTag.Tag.Valid {
			decTag, err := crypto.Decrypt(sqlTag.Tag.String)
			if err != nil {
				return nil, nil, err
			}
			t = tag.TagDTO{Id: uint(sqlTag.Id.Int64), Tag: decTag}
			tags[cat.Id] = append(tags[cat.Id], t)
		}
		categories[cat.Id] = cat

		if err != nil {
			return nil, nil, err
		}
	}

	return categories, tags, nil
}

func (c *CategoriesRepository) Create(category *category.Category) error {
	_, err := c.DB.Query(
		"INSERT INTO Categories (category, color, isLocked, idUser) VALUES (?, ?, ?, ?)",
		category.Category, category.Color, category.IsLocked, category.IdUser,
	)

	if err != nil {
		return err
	}

	return nil
}

func (c *CategoriesRepository) Update(category *category.Category) error {
	res, err := c.DB.Exec(
		"UPDATE Categories SET category = ?, color = ? WHERE id = ?",
		category.Category, category.Color, category.Id,
	)

	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	return nil
}

func (c *CategoriesRepository) Delete(idCategory uint, idUser uint64, moveTags bool) error {
	ctx := context.Background()
	tx, err := c.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	var category category.Category
	row := tx.QueryRow("SELECT isLocked FROM Categories WHERE id = ?", idCategory)
	err = row.Scan(&category.IsLocked)
	if err != nil {
		tx.Rollback()
		return apperror.NewInternal()
	}

	if category.IsLocked {
		tx.Rollback()
		return apperror.NewStatusForbidden()
	}

	if moveTags {
		var idCategoryOther uint
		var idCategoryDate uint
		row := c.DB.QueryRow("SELECT id FROM Categories WHERE idUser = ? LIMIT 1;", idUser) // the date category must be the first one
		err = row.Scan(&idCategoryDate)
		if err != nil {
			tx.Rollback()
			return err
		}
		idCategoryOther = idCategoryDate + 2

		res, err := c.DB.Exec(`UPDATE Tags SET idCategory = ? WHERE idCategory = ?;`, idCategoryOther, idCategory)
		if err != nil {
			tx.Rollback()
			return err
		}

		rowsAffected, err := res.RowsAffected()
		if rowsAffected == 0 || err != nil {
			tx.Rollback()
			return apperror.NewInternal()
		}
	}

	res, err := c.DB.Exec("DELETE FROM Categories WHERE id = ?", idCategory)
	if err != nil {
		tx.Rollback()
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	err = tx.Commit()
	if err != nil {
		return err
	}

	return nil
}
