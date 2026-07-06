package persistence

import (
	"context"
	"database/sql"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/jmoiron/sqlx"
)

type CategoriesRepository struct {
	DB     *sqlx.DB
	Crypto application.Encryptor
}

func NewCategoriesRepository(db *sqlx.DB, crypto application.Encryptor) category.Repository {
	return &CategoriesRepository{
		DB:     db,
		Crypto: crypto,
	}
}

func (c *CategoriesRepository) FindById(ctx context.Context, id uint) (*category.Category, error) {
	var storedCategory category.Category
	err := c.DB.GetContext(ctx, &storedCategory, "SELECT category, color, isLocked FROM Categories WHERE id = ?", id)
	if err != nil {
		return nil, err
	}
	return &storedCategory, nil
}

func (c *CategoriesRepository) FindLastIdByIdUser(ctx context.Context, idUser uint64) (uint, error) {
	var idCategoryDate uint
	// the date category must be the first one
	err := c.DB.GetContext(ctx, &idCategoryDate, "SELECT id FROM Categories WHERE idUser = ? LIMIT 1;", idUser)
	if err != nil {
		return 0, err
	}
	return idCategoryDate, nil
}

func (c *CategoriesRepository) CheckLastIdByIdAndIdUser(ctx context.Context, idUser uint64, idCategory uint) error {
	var resId uint
	return c.DB.GetContext(ctx, &resId, "SELECT id FROM Categories WHERE id = ? AND idUser = ? LIMIT 1;", idCategory, idUser)
}

// Returns all categories with all tags, but without the tags of the category persons
func (c *CategoriesRepository) GetAllCategoriesWithTags(ctx context.Context, idUser uint64) (map[uint]category.Category, map[uint][]category.TagDTO, error) {
	type SQLTag struct {
		Id          sql.NullInt64  `json:"id"`
		Tag         sql.NullString `json:"tag"`
		IdParentTag sql.NullInt64  `json:"idParentTag"`
	}

	results, err := c.DB.QueryxContext(ctx, `
		SELECT Categories.Id, category, color, isLocked, Tags.id, tag, Tags.idParentTag
		FROM Categories
		LEFT JOIN Tags
		ON Categories.id = Tags.idCategory
		WHERE idUser = ?
		ORDER BY Categories.id, Tags.id
	`, idUser)

	if err != nil {
		return nil, nil, err
	}
	defer results.Close()

	var tags = make(map[uint][]category.TagDTO)
	var categories = make(map[uint]category.Category)
	for results.Next() {
		var sqlTag SQLTag
		var t category.TagDTO
		var cat category.Category
		err = results.Scan(&cat.Id, &cat.Category, &cat.Color, &cat.IsLocked, &sqlTag.Id, &sqlTag.Tag, &sqlTag.IdParentTag)
		if err != nil {
			return nil, nil, err
		}

		// if the category is empty, Tag will be null
		if sqlTag.Id.Valid && sqlTag.Tag.Valid {
			decTag, err := c.Crypto.Decrypt(sqlTag.Tag.String)
			if err != nil {
				return nil, nil, err
			}
			t = category.TagDTO{Id: uint(sqlTag.Id.Int64), Tag: decTag}
			if sqlTag.IdParentTag.Valid {
				idParentTag := uint(sqlTag.IdParentTag.Int64)
				t.IdParentTag = &idParentTag
			}
			tags[cat.Id] = append(tags[cat.Id], t)
		}
		categories[cat.Id] = cat
	}
	if err := results.Err(); err != nil {
		return nil, nil, err
	}

	return categories, tags, nil
}

func (c *CategoriesRepository) Create(ctx context.Context, category *category.Category) error {
	_, err := c.DB.ExecContext(ctx,
		"INSERT INTO Categories (category, color, isLocked, idUser) VALUES (?, ?, ?, ?)",
		category.Category, category.Color, category.IsLocked, category.IdUser,
	)

	return err
}

func (c *CategoriesRepository) Update(ctx context.Context, category *category.Category) error {
	res, err := c.DB.ExecContext(ctx,
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

func (c *CategoriesRepository) Delete(ctx context.Context, idCategory uint, idUser uint64, moveTags bool) error {
	tx, err := c.DB.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	var category category.Category
	row := tx.QueryRowContext(ctx, "SELECT isLocked FROM Categories WHERE id = ?", idCategory)
	err = row.Scan(&category.IsLocked)
	if err != nil {
		return apperror.NewInternal()
	}

	if category.IsLocked {
		return apperror.NewStatusForbidden()
	}

	if moveTags {
		var idCategoryDate uint
		// the date category must be the first one
		row := tx.QueryRowContext(ctx, "SELECT id FROM Categories WHERE idUser = ? LIMIT 1;", idUser)
		err = row.Scan(&idCategoryDate)
		if err != nil {
			return err
		}
		idCategoryOther := idCategoryDate + 2

		res, err := tx.ExecContext(ctx, `UPDATE Tags SET idCategory = ? WHERE idCategory = ?;`, idCategoryOther, idCategory)
		if err != nil {
			return err
		}

		rowsAffected, err := res.RowsAffected()
		if rowsAffected == 0 || err != nil {
			return apperror.NewInternal()
		}
	}

	res, err := tx.ExecContext(ctx, "DELETE FROM Categories WHERE id = ?", idCategory)
	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	return tx.Commit()
}
