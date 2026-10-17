package persistence

import (
	"context"
	"database/sql"
	"strconv"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/e2ee"
	"github.com/jmoiron/sqlx"
)

// Tag groups belong to the Category aggregate, so their persistence
// operations are methods of CategoriesRepository, like the tags'.

const tagGroupNameTaken = "A group with this name already exists in this category"

// GetAllTagGroups returns the user's tag groups by category id, with their
// members (ordered by id, so the payload is stable).
func (c *CategoriesRepository) GetAllTagGroups(ctx context.Context, idUser uint64) (map[uint][]category.TagGroupDTO, error) {
	rows, err := c.DB.QueryxContext(ctx, `
		SELECT g.id, g.idCategory, g.name, m.idTag
		FROM TagGroups g
		INNER JOIN Categories ON Categories.id = g.idCategory
		LEFT JOIN TagGroupMembers m ON m.idGroup = g.id
		WHERE idUser = ?
		ORDER BY g.idCategory, g.id, m.idTag
	`, idUser)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	groups := make(map[uint][]category.TagGroupDTO)
	for rows.Next() {
		var id, idCategory uint
		var name string
		var idTag sql.NullInt64
		if err := rows.Scan(&id, &idCategory, &name, &idTag); err != nil {
			return nil, err
		}

		// One row per member: a new group starts when the id changes.
		list := groups[idCategory]
		if len(list) == 0 || list[len(list)-1].Id != id {
			// E2EE names are opaque blobs returned verbatim.
			decName := name
			if !e2ee.Enabled(ctx) {
				decName, err = c.Crypto.Decrypt(name, idUser)
				if err != nil {
					return nil, err
				}
			}
			list = append(list, category.TagGroupDTO{Id: id, Name: decName, Members: []uint{}})
		}
		// A group whose members were all deleted has no member row.
		if idTag.Valid {
			last := &list[len(list)-1]
			last.Members = append(last.Members, uint(idTag.Int64))
		}
		groups[idCategory] = list
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return groups, nil
}

func (c *CategoriesRepository) CreateTagGroup(ctx context.Context, nameEncrypt string, nameIndex *string, idCategory uint, members []uint) (uint, error) {
	tx, err := c.DB.BeginTxx(ctx, nil)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	res, err := tx.ExecContext(ctx, "INSERT INTO TagGroups (name, nameIndex, idCategory) VALUES (?, ?, ?)", nameEncrypt, nameIndex, idCategory)
	if err != nil {
		return 0, tagNameConflict(err, tagGroupNameTaken)
	}

	idGroup, err := res.LastInsertId()
	if err != nil {
		return 0, err
	}

	if err := insertTagGroupMembers(ctx, tx, uint(idGroup), members); err != nil {
		return 0, err
	}

	if err := tx.Commit(); err != nil {
		return 0, err
	}
	return uint(idGroup), nil
}

func (c *CategoriesRepository) UpdateTagGroup(ctx context.Context, nameEncrypt string, nameIndex *string, idGroup uint, members []uint) error {
	tx, err := c.DB.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	// The affected-rows count is deliberately not checked: MySQL reports 0
	// for a no-op update (a replayed PATCH), and ownership is already
	// verified by the service through FindTagGroupForUser.
	_, err = tx.ExecContext(ctx, "UPDATE TagGroups SET name = ?, nameIndex = ? WHERE id = ?", nameEncrypt, nameIndex, idGroup)
	if err != nil {
		return tagNameConflict(err, tagGroupNameTaken)
	}

	// Full state: the member list replaces the stored one.
	if _, err := tx.ExecContext(ctx, "DELETE FROM TagGroupMembers WHERE idGroup = ?", idGroup); err != nil {
		return err
	}
	if err := insertTagGroupMembers(ctx, tx, idGroup, members); err != nil {
		return err
	}

	return tx.Commit()
}

// insertTagGroupMembers links the (deduplicated, validated) member tags to
// the group.
func insertTagGroupMembers(ctx context.Context, tx *sqlx.Tx, idGroup uint, members []uint) error {
	stmt, err := tx.PrepareContext(ctx, "INSERT INTO TagGroupMembers (idGroup, idTag) VALUES (?, ?)")
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, idTag := range members {
		if _, err := stmt.ExecContext(ctx, idGroup, idTag); err != nil {
			return err
		}
	}
	return nil
}

// DeleteTagGroup removes a group, scoped to its owner; its member rows
// cascade. The tags themselves and their events are untouched.
func (c *CategoriesRepository) DeleteTagGroup(ctx context.Context, idGroup uint, idUser uint64) error {
	res, err := c.DB.ExecContext(ctx, `
		DELETE g FROM TagGroups g
		INNER JOIN Categories ON Categories.id = g.idCategory
		WHERE g.id = ?
		AND idUser = ?
	`, idGroup, idUser)
	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return apperror.NewNotFound("tagGroup", strconv.FormatUint(uint64(idGroup), 10))
	}
	return nil
}

// FindTagGroupForUser loads a group (without its members) and checks it
// belongs to the given user.
func (c *CategoriesRepository) FindTagGroupForUser(ctx context.Context, idGroup uint, idUser uint64) (*category.TagGroup, error) {
	var group category.TagGroup
	err := c.DB.GetContext(ctx, &group, `
		SELECT g.id, g.name, g.idCategory, g.nameIndex
		FROM TagGroups g
		INNER JOIN Categories ON Categories.id = g.idCategory
		WHERE g.id = ?
		AND idUser = ?
	`, idGroup, idUser)
	if err != nil {
		return nil, err
	}

	return &group, nil
}

// CheckMainTagsInCategory verifies that every id in tagsId is a main tag of
// the given category of the user: a group only holds main tags of its own
// category, and never another user's.
func (c *CategoriesRepository) CheckMainTagsInCategory(ctx context.Context, tagsId []uint, idCategory uint, idUser uint64) error {
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
		AND t.idParentTag IS NULL
		AND t.idCategory = ?
		AND c.idUser = ?
	`, ids, idCategory, idUser)
	if err != nil {
		return err
	}

	var matching int
	if err := c.DB.GetContext(ctx, &matching, c.DB.Rebind(query), args...); err != nil {
		return err
	}

	if matching != len(ids) {
		return apperror.NewBadRequest("The members must be main tags of the group's category")
	}
	return nil
}
