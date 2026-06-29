package repository

import (
	"context"
	"database/sql"

	"github.com/alkariin/homl/homl-web/helper"
	"github.com/alkariin/homl/homl-web/model"
)

type CategoriesRepository struct {
	DB *sql.DB
}

func NewCategoriesRepository(db *sql.DB) model.CategoriesRepository {
	return &CategoriesRepository{
		DB: db,
	}
}

func (c *CategoriesRepository) FindById(id uint) (*model.Category, error) {
	var storedCategory model.Category
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
func (c *CategoriesRepository) GetAllCategoriesWithTags(idUser uint64) (map[uint]model.Category, map[uint][]model.TagDTO, error) {
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

	var tags = make(map[uint][]model.TagDTO)
	var categories = make(map[uint]model.Category)
	for results.Next() {
		var sqlTag SQLTag
		var tag model.TagDTO
		var category model.Category
		err = results.Scan(&category.Id, &category.Category, &category.Color, &category.IsLocked, &sqlTag.Id, &sqlTag.Tag)
		// if the category is empty, Tag will be null
		if sqlTag.Id.Valid && sqlTag.Tag.Valid {
			decTag, err := helper.Decrypt(sqlTag.Tag.String)
			if err != nil {
				return nil, nil, err
			}
			tag = model.TagDTO{Id: uint(sqlTag.Id.Int64), Tag: decTag}
			tags[category.Id] = append(tags[category.Id], tag)
		}
		categories[category.Id] = category

		if err != nil {
			return nil, nil, err
		}
	}

	return categories, tags, nil
}

func (c *CategoriesRepository) Create(category *model.Category) error {
	_, err := c.DB.Query(
		"INSERT INTO Categories (category, color, isLocked, idUser) VALUES (?, ?, ?, ?)",
		category.Category, category.Color, category.IsLocked, category.IdUser,
	)

	if err != nil {
		return err
	}

	return nil
}

func (c *CategoriesRepository) Update(category *model.Category) error {
	res, err := c.DB.Exec(
		"UPDATE Categories SET category = ?, color = ? WHERE id = ?",
		category.Category, category.Color, category.Id,
	)

	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return helper.NewInternal()
	}

	return nil
}

func (c *CategoriesRepository) Delete(idCategory uint, idUser uint64, moveTags bool) error {
	ctx := context.Background()
	tx, err := c.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	var category model.Category
	row := tx.QueryRow("SELECT isLocked FROM Categories WHERE id = ?", idCategory)
	err = row.Scan(&category.IsLocked)
	if err != nil {
		tx.Rollback()
		return helper.NewInternal()
	}

	if category.IsLocked {
		tx.Rollback()
		return helper.NewStatusForbidden()
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
			return helper.NewInternal()
		}
	}

	res, err := c.DB.Exec("DELETE FROM Categories WHERE id = ?", idCategory)
	if err != nil {
		tx.Rollback()
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return helper.NewInternal()
	}

	err = tx.Commit()
	if err != nil {
		return err
	}

	return nil
}
