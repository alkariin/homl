package persistence

import (
	"context"
	"database/sql"
	"strconv"

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

func (c *CategoriesRepository) FindByIdForUser(ctx context.Context, id uint, idUser uint64) (*category.Category, error) {
	var storedCategory category.Category
	err := c.DB.GetContext(ctx, &storedCategory, "SELECT id, category, color, isLocked, kind FROM Categories WHERE id = ? AND idUser = ?", id, idUser)
	if err != nil {
		if err == sql.ErrNoRows {
			// Unknown id or a category owned by someone else: same answer, so
			// the endpoint cannot be used to probe other users' category ids.
			return nil, apperror.NewNotFound("category", strconv.FormatUint(uint64(id), 10))
		}
		return nil, err
	}
	return &storedCategory, nil
}

func (c *CategoriesRepository) FindIdByKind(ctx context.Context, idUser uint64, kind category.Kind) (uint, error) {
	var id uint
	err := c.DB.GetContext(ctx, &id, "SELECT id FROM Categories WHERE idUser = ? AND kind = ?", idUser, kind)
	if err != nil {
		return 0, err
	}
	return id, nil
}

// Returns all categories with all tags, but without the tags of the category persons
func (c *CategoriesRepository) GetAllCategoriesWithTags(ctx context.Context, idUser uint64) (map[uint]category.Category, map[uint][]category.TagDTO, error) {
	type SQLTag struct {
		Id          sql.NullInt64  `json:"id"`
		Tag         sql.NullString `json:"tag"`
		IdParentTag sql.NullInt64  `json:"idParentTag"`
	}

	results, err := c.DB.QueryxContext(ctx, `
		SELECT Categories.Id, category, color, isLocked, kind, Tags.id, tag, Tags.idParentTag
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
		err = results.Scan(&cat.Id, &cat.Category, &cat.Color, &cat.IsLocked, &cat.Kind, &sqlTag.Id, &sqlTag.Tag, &sqlTag.IdParentTag)
		if err != nil {
			return nil, nil, err
		}

		// if the category is empty, Tag will be null
		if sqlTag.Id.Valid && sqlTag.Tag.Valid {
			decTag, err := c.Crypto.Decrypt(sqlTag.Tag.String, idUser)
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

func (c *CategoriesRepository) Create(ctx context.Context, cat *category.Category) error {
	kind := cat.Kind
	if kind == "" {
		kind = category.KindCustom
	}
	_, err := c.DB.ExecContext(ctx,
		"INSERT INTO Categories (category, color, isLocked, kind, idUser) VALUES (?, ?, ?, ?, ?)",
		cat.Category, cat.Color, cat.IsLocked, kind, cat.IdUser,
	)

	return err
}

func (c *CategoriesRepository) Update(ctx context.Context, category *category.Category) error {
	// Scoped to the owner. The affected-rows count is deliberately not
	// checked: MySQL reports 0 for no-op updates (same values), and ownership
	// is already verified by the service through FindByIdForUser.
	_, err := c.DB.ExecContext(ctx,
		"UPDATE Categories SET category = ?, color = ? WHERE id = ? AND idUser = ?",
		category.Category, category.Color, category.Id, category.IdUser,
	)

	return err
}

func (c *CategoriesRepository) Delete(ctx context.Context, idCategory uint, idUser uint64, moveTags bool) error {
	tx, err := c.DB.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	// Load the category scoped to its owner: an id belonging to another user
	// is indistinguishable from a missing one.
	var isLocked bool
	row := tx.QueryRowContext(ctx, "SELECT isLocked FROM Categories WHERE id = ? AND idUser = ?", idCategory, idUser)
	err = row.Scan(&isLocked)
	if err != nil {
		if err == sql.ErrNoRows {
			return apperror.NewNotFound("category", strconv.FormatUint(uint64(idCategory), 10))
		}
		return err
	}

	if isLocked {
		return apperror.NewStatusForbidden()
	}

	if moveTags {
		var idCategoryOther uint
		row := tx.QueryRowContext(ctx, "SELECT id FROM Categories WHERE idUser = ? AND kind = ?", idUser, category.KindOther)
		err = row.Scan(&idCategoryOther)
		if err != nil {
			return err
		}

		// No affected-rows check: deleting an empty category is a legal no-op.
		_, err := tx.ExecContext(ctx, `UPDATE Tags SET idCategory = ? WHERE idCategory = ?;`, idCategoryOther, idCategory)
		if err != nil {
			return err
		}
	}

	res, err := tx.ExecContext(ctx, "DELETE FROM Categories WHERE id = ? AND idUser = ?", idCategory, idUser)
	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	return tx.Commit()
}
