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

func (c *CategoriesRepository) CreateTag(ctx context.Context, tagNameEncrypt string, tagIndex *string, idCategory uint, idParentTag *uint) (uint, error) {
	res, err := c.DB.ExecContext(ctx, "INSERT INTO Tags (tag, tagIndex, idCategory, idParentTag) VALUES (?, ?, ?, ?)", tagNameEncrypt, tagIndex, idCategory, idParentTag)
	if err != nil {
		return 0, err
	}

	idTag, err := res.LastInsertId()
	if err != nil {
		return 0, err
	}

	return uint(idTag), nil
}

func (c *CategoriesRepository) UpdateTag(ctx context.Context, tagNameEncrypt string, tagIndex *string, idCategory uint, idTag uint, idParentTag *uint) error {
	tx, err := c.DB.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	res, err := tx.ExecContext(ctx, "UPDATE Tags SET tag = ?, tagIndex = ?, idCategory = ?, idParentTag = ? WHERE id = ?", tagNameEncrypt, tagIndex, idCategory, idParentTag, idTag)

	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	// A synonym must live in the same category as its main tag: when a main
	// tag moves (idParentTag nil), its synonyms follow. No-op otherwise.
	if idParentTag == nil {
		_, err = tx.ExecContext(ctx, "UPDATE Tags SET idCategory = ? WHERE idParentTag = ?", idCategory, idTag)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

// DeleteTag removes a tag while keeping its synonym group and the events
// tagged with it consistent:
//   - deleting a synonym repoints its EventsTags rows to the parent tag;
//   - deleting a main tag deletes its whole synonym group; deleteEvents
//     decides whether every event tagged with the group is deleted too or
//     preserved (only the tag is removed from them).
func (c *CategoriesRepository) DeleteTag(ctx context.Context, idTag uint, idUser uint64, deleteEvents bool) error {
	tx, err := c.DB.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	// Load the tag, scoped to the user.
	var idParentTag *uint
	err = tx.GetContext(ctx, &idParentTag, `
		SELECT t.idParentTag FROM Tags t
		INNER JOIN Categories
		ON t.idCategory = Categories.id
		WHERE t.id = ?
		AND idUser = ?
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
	} else if deleteEvents {
		// Main tag: delete every event tagged with the group (whatever other
		// tags it carries) before the cascade removes their EventsTags rows.
		// The derived table keeps MySQL from selecting the target table of
		// the DELETE.
		_, err = tx.ExecContext(ctx, `
			DELETE FROM Events
			WHERE idUser = ?
			AND id IN (
				SELECT idEvent FROM (
					SELECT DISTINCT et.idEvent
					FROM EventsTags et
					INNER JOIN Tags t ON t.id = et.idTag
					WHERE COALESCE(t.idParentTag, t.id) = ?
				) AS doomed
			)
		`, idUser, idTag)
		if err != nil {
			return err
		}
	}

	// Deleting a main tag cascades to its synonym rows (Tags.idParentTag FK)
	// and to the EventsTags rows of the whole group.
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

// exclusiveTagGroupEventsQuery selects the events linked to a tag's synonym
// group (root = COALESCE(idParentTag, id)) that have no other non-date tag
// outside the group — the ones a deletion that keeps the events would leave
// date-only. Args: idTag (group root), idTag again.
const exclusiveTagGroupEventsQuery = `
	SELECT e.id FROM Events e
	WHERE EXISTS (
		SELECT 1 FROM EventsTags et
		INNER JOIN Tags t ON t.id = et.idTag
		WHERE et.idEvent = e.id
		AND COALESCE(t.idParentTag, t.id) = ?
	)
	AND NOT EXISTS (
		SELECT 1 FROM EventsTags et2
		INNER JOIN Tags t2 ON t2.id = et2.idTag
		INNER JOIN Categories c2 ON c2.id = t2.idCategory
		WHERE et2.idEvent = e.id
		AND COALESCE(t2.idParentTag, t2.id) <> ?
		AND c2.kind <> 'date'
	)`

// GetTagUsage counts the events referencing the tag's synonym group and, out
// of those, the ones that have no other non-date tag (the events a group
// deletion that keeps the events would leave date-only).
func (c *CategoriesRepository) GetTagUsage(ctx context.Context, idTag uint, idUser uint64) (*category.TagUsage, error) {
	var usage category.TagUsage

	err := c.DB.GetContext(ctx, &usage.Events, `
		SELECT COUNT(DISTINCT et.idEvent)
		FROM EventsTags et
		INNER JOIN Tags t ON t.id = et.idTag
		WHERE et.idUser = ?
		AND COALESCE(t.idParentTag, t.id) = ?
	`, idUser, idTag)
	if err != nil {
		return nil, err
	}

	err = c.DB.GetContext(ctx, &usage.ExclusiveEvents, `
		SELECT COUNT(*) FROM (`+exclusiveTagGroupEventsQuery+`
		AND e.idUser = ?) AS exclusive
	`, idTag, idTag, idUser)
	if err != nil {
		return nil, err
	}

	return &usage, nil
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
	err := c.DB.QueryRowxContext(ctx, `
		SELECT t.id, t.tag, t.idCategory, t.idParentTag
		FROM Tags t
		INNER JOIN Categories
		ON t.idCategory = Categories.id
		WHERE t.id = ?
		AND idUser = ?
	`, idTag, idUser).Scan(&tag.Id, &tag.Tag, &tag.IdCategory, &tag.IdParentTag)
	if err != nil {
		return nil, err
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
