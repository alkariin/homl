package persistence

import (
	"context"
	"database/sql"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/jmoiron/sqlx"
)

// Tags belong to the Category aggregate, so their persistence operations are
// methods of CategoriesRepository.

func (c *CategoriesRepository) CreateTag(ctx context.Context, tagNameEncrypt string, idCategory uint, idParentTag *uint) (uint, error) {
	res, err := c.DB.ExecContext(ctx, "INSERT INTO Tags (tag, idCategory, idParentTag) VALUES (?, ?, ?)", tagNameEncrypt, idCategory, idParentTag)
	if err != nil {
		return 0, err
	}

	idTag, err := res.LastInsertId()
	if err != nil {
		return 0, err
	}

	return uint(idTag), nil
}

func (c *CategoriesRepository) UpdateTag(ctx context.Context, tagNameEncrypt string, idCategory uint, idTag uint, idParentTag *uint) error {
	res, err := c.DB.ExecContext(ctx, "UPDATE Tags SET tag = ?, idCategory = ?, idParentTag = ? WHERE id = ?", tagNameEncrypt, idCategory, idParentTag, idTag)

	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	return nil
}

// DeleteTag removes a non-person tag while keeping its synonym group and the
// events tagged with it consistent:
//   - deleting a synonym repoints its EventsTags rows to the parent tag;
//   - deleting a main tag promotes its oldest synonym as the new main tag.
func (c *CategoriesRepository) DeleteTag(ctx context.Context, idTag uint, idUser uint64) error {
	tx, err := c.DB.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	// Load the tag, scoped to the user and excluding person main tags (they
	// mirror the person's name and are managed through the person endpoints).
	var idParentTag *uint
	err = tx.GetContext(ctx, &idParentTag, `
		SELECT t.idParentTag FROM Tags t
		INNER JOIN Categories
		ON t.idCategory = Categories.id
		WHERE t.id = ?
		AND idUser = ?
		AND idPerson IS NULL
	`, idTag, idUser)
	if err != nil {
		if err == sql.ErrNoRows {
			return apperror.NewInternal()
		}
		return err
	}

	if idParentTag != nil {
		// Synonym: repoint its event links to the parent, dropping the ones
		// whose event is already linked to the parent (avoids duplicates).
		_, err = tx.ExecContext(ctx, `
			DELETE FROM EventsTags
			WHERE idTag = ?
			AND idEvent IN (
				SELECT idEvent FROM (
					SELECT idEvent FROM EventsTags WHERE idTag = ?
				) AS parentEvents
			)
		`, idTag, *idParentTag)
		if err != nil {
			return err
		}

		_, err = tx.ExecContext(ctx, "UPDATE EventsTags SET idTag = ? WHERE idTag = ?", *idParentTag, idTag)
		if err != nil {
			return err
		}
	} else {
		// Main tag: promote the oldest synonym, if any, before deleting.
		var newMainId uint
		err = tx.GetContext(ctx, &newMainId, "SELECT COALESCE(MIN(id), 0) FROM Tags WHERE idParentTag = ?", idTag)
		if err != nil {
			return err
		}

		if newMainId != 0 {
			_, err = tx.ExecContext(ctx, "UPDATE Tags SET idParentTag = NULL WHERE id = ?", newMainId)
			if err != nil {
				return err
			}

			_, err = tx.ExecContext(ctx, "UPDATE Tags SET idParentTag = ? WHERE idParentTag = ?", newMainId, idTag)
			if err != nil {
				return err
			}
		}
	}

	res, err := tx.ExecContext(ctx, "DELETE FROM Tags WHERE id = ?", idTag)
	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	return tx.Commit()
}

// CheckTagsBelongToUser verifies that every id in tagsId is a tag living in
// one of the user's categories. Without this check a client could attach
// another user's tag ids to its own events — and read their decrypted names
// back through GetEvents.
func (c *CategoriesRepository) CheckTagsBelongToUser(ctx context.Context, tagsId []uint, idUser uint64) error {
	if len(tagsId) == 0 {
		return nil
	}

	// Deduplicate so the count comparison below cannot be fooled.
	unique := make(map[uint]struct{}, len(tagsId))
	for _, id := range tagsId {
		unique[id] = struct{}{}
	}
	ids := make([]uint, 0, len(unique))
	for id := range unique {
		ids = append(ids, id)
	}

	query, args, err := sqlx.In(`
		SELECT COUNT(*)
		FROM Tags t
		INNER JOIN Categories c ON t.idCategory = c.id
		WHERE t.id IN (?)
		AND c.idUser = ?
	`, ids, idUser)
	if err != nil {
		return err
	}

	var owned int
	if err := c.DB.GetContext(ctx, &owned, c.DB.Rebind(query), args...); err != nil {
		return err
	}

	if owned != len(ids) {
		return apperror.NewBadRequest("One or more tag ids are not valid")
	}
	return nil
}

// FindTagForUser loads a tag and checks it belongs to the given user.
func (c *CategoriesRepository) FindTagForUser(ctx context.Context, idTag uint, idUser uint64) (*category.Tag, error) {
	var tag category.Tag
	var idPerson *uint
	err := c.DB.QueryRowxContext(ctx, `
		SELECT t.id, t.tag, t.idCategory, t.idPerson, t.idParentTag
		FROM Tags t
		INNER JOIN Categories
		ON t.idCategory = Categories.id
		WHERE t.id = ?
		AND idUser = ?
	`, idTag, idUser).Scan(&tag.Id, &tag.Tag, &tag.IdCategory, &idPerson, &tag.IdParentTag)
	if err != nil {
		return nil, err
	}

	if idPerson != nil {
		tag.IdPerson = *idPerson
	}

	return &tag, nil
}

func (c *CategoriesRepository) HasSynonyms(ctx context.Context, idTag uint) (bool, error) {
	var hasSynonyms bool
	err := c.DB.GetContext(ctx, &hasSynonyms, "SELECT EXISTS(SELECT 1 FROM Tags WHERE idParentTag = ?)", idTag)
	return hasSynonyms, err
}

func (c *CategoriesRepository) FindTagIdByTagAndIdCategory(ctx context.Context, tag string, idCategoryDate uint) (uint, error) {
	var idTag uint
	err := c.DB.GetContext(ctx, &idTag, "SELECT COALESCE(MIN(id), 0) FROM Tags WHERE tag = ? AND idCategory = ?;", tag, idCategoryDate)
	if err != nil {
		return 0, err
	}

	return idTag, nil
}

func (c *CategoriesRepository) FindMainTagIdOfPerson(ctx context.Context, idPerson uint) (uint, error) {
	var mainPersonTagId uint
	err := c.DB.GetContext(ctx, &mainPersonTagId, "SELECT id FROM Tags WHERE idPerson = ? AND idParentTag IS NULL", idPerson)
	if err != nil {
		return 0, err
	}
	return mainPersonTagId, nil
}

// CreateAllTags inserts the tags that do not exist yet and returns every tag id.
// Rolling back on failure is the caller's responsibility (defer tx.Rollback()).
func CreateAllTags(ctx context.Context, tx *sqlx.Tx, crypto application.Encryptor, tags []category.Tag, idUser uint64) ([]uint, error) {
	// Create date tags if needed
	var tagsId = []uint{}
	for _, tag := range tags {
		if tag.Id == 0 {
			encTag, err := crypto.Encrypt(tag.Tag, idUser)
			if err != nil {
				return nil, err
			}

			res, err := tx.ExecContext(ctx, "INSERT INTO Tags (tag, idCategory) VALUES (?, ?)", encTag, tag.IdCategory)
			// Refused if the tag already exists in another category
			if err != nil {
				return nil, err
			}

			insertedId, err := res.LastInsertId()
			if err != nil {
				return nil, err
			}
			tag.Id = uint(insertedId)
		}

		tagsId = append(tagsId, tag.Id)
	}

	return tagsId, nil
}
