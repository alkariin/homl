package persistence

import (
	"context"
	"errors"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/e2ee"
	"github.com/go-sql-driver/mysql"
	"github.com/jmoiron/sqlx"
)

type E2EERepository struct {
	DB     *sqlx.DB
	Crypto application.Encryptor
}

func NewE2EERepository(db *sqlx.DB, crypto application.Encryptor) e2ee.Repository {
	return &E2EERepository{
		DB:     db,
		Crypto: crypto,
	}
}

func (r *E2EERepository) IsEnabled(ctx context.Context, idUser uint64) (bool, error) {
	var enabled bool
	err := r.DB.GetContext(ctx, &enabled, "SELECT isE2eeEnabled FROM Users WHERE id = ?", idUser)
	return enabled, err
}

// Migrate swaps the user's whole dataset and flips the E2EE flag in a single
// transaction: either everything is applied or nothing is, so a lost response
// or a killed client can simply retry from scratch.
func (r *E2EERepository) Migrate(ctx context.Context, idUser uint64, enable bool, keyCheck *string, data *e2ee.MigrationData) error {
	tx, err := r.DB.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	// Lock the user row so two concurrent migrations serialize; requesting
	// the direction already in place conflicts, which makes a retry after a
	// lost response harmless.
	var current bool
	if err := tx.GetContext(ctx, &current, "SELECT isE2eeEnabled FROM Users WHERE id = ? FOR UPDATE", idUser); err != nil {
		return err
	}
	if current == enable {
		return apperror.NewConflict("isE2eeEnabled", boolLabel(current))
	}

	// The payload must cover the stored rows exactly: anything created or
	// deleted since the client fetched conflicts (refetch and retry).
	if err := checkIdSetMatches(ctx, tx, "SELECT id FROM Categories WHERE idUser = ?", idUser, categoryIds(data)); err != nil {
		return err
	}
	if err := checkIdSetMatches(ctx, tx, "SELECT t.id FROM Tags t INNER JOIN Categories c ON t.idCategory = c.id WHERE c.idUser = ?", idUser, tagIds(data)); err != nil {
		return err
	}
	if err := checkIdSetMatches(ctx, tx, "SELECT id FROM Events WHERE idUser = ?", idUser, eventIds(data)); err != nil {
		return err
	}

	catStmt, err := tx.PrepareContext(ctx, "UPDATE Categories SET category = ? WHERE id = ? AND idUser = ?")
	if err != nil {
		return err
	}
	defer catStmt.Close()
	for _, c := range data.Categories {
		value := c.Category
		if !enable {
			if value, err = r.Crypto.Encrypt(c.Category, idUser); err != nil {
				return err
			}
		}
		if _, err := catStmt.ExecContext(ctx, value, c.Id, idUser); err != nil {
			return err
		}
	}

	// Tag ids were verified against the user's categories above, so the
	// update needs no further scoping.
	tagStmt, err := tx.PrepareContext(ctx, "UPDATE Tags SET tag = ?, tagIndex = ? WHERE id = ?")
	if err != nil {
		return err
	}
	defer tagStmt.Close()
	for _, t := range data.Tags {
		value := t.Tag
		if !enable {
			if value, err = r.Crypto.Encrypt(t.Tag, idUser); err != nil {
				return err
			}
		}
		if _, err := tagStmt.ExecContext(ctx, value, t.TagIndex, t.Id); err != nil {
			// Two tags of a category collapsing onto the same value (enable:
			// same tagIndex, disable: same normalized name) violate the
			// unique keys: the client must merge them and retry.
			var mysqlErr *mysql.MySQLError
			if errors.As(err, &mysqlErr) && mysqlErr.Number == mysqlDuplicateEntry {
				return apperror.NewConflict("tag", "duplicate in category")
			}
			return err
		}
	}

	evtStmt, err := tx.PrepareContext(ctx, "UPDATE Events SET description = ? WHERE id = ? AND idUser = ?")
	if err != nil {
		return err
	}
	defer evtStmt.Close()
	for _, ev := range data.Events {
		value := ev.Description
		if !enable {
			if value, err = r.Crypto.Encrypt(ev.Description, idUser); err != nil {
				return err
			}
		}
		if _, err := evtStmt.ExecContext(ctx, value, ev.Id, idUser); err != nil {
			return err
		}
	}

	if _, err := tx.ExecContext(ctx, "UPDATE Users SET isE2eeEnabled = ?, e2eeKeyCheck = ? WHERE id = ?", enable, keyCheck, idUser); err != nil {
		return err
	}

	return tx.Commit()
}

// Purge deletes everything the lost key made unreadable and reseeds the
// default categories, exactly like a fresh registration.
func (r *E2EERepository) Purge(ctx context.Context, idUser uint64) error {
	tx, err := r.DB.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	var enabled bool
	if err := tx.GetContext(ctx, &enabled, "SELECT isE2eeEnabled FROM Users WHERE id = ? FOR UPDATE", idUser); err != nil {
		return err
	}
	if !enabled {
		return apperror.NewConflict("isE2eeEnabled", boolLabel(false))
	}

	if _, err := tx.ExecContext(ctx, "DELETE FROM Events WHERE idUser = ?", idUser); err != nil {
		return err
	}
	// Deleting the categories cascades to their tags and any remaining
	// EventsTags rows.
	if _, err := tx.ExecContext(ctx, "DELETE FROM Categories WHERE idUser = ?", idUser); err != nil {
		return err
	}

	if err := seedDefaultCategories(ctx, tx, r.Crypto, idUser); err != nil {
		return err
	}

	if _, err := tx.ExecContext(ctx, "UPDATE Users SET isE2eeEnabled = 0, e2eeKeyCheck = NULL WHERE id = ?", idUser); err != nil {
		return err
	}

	return tx.Commit()
}

// checkIdSetMatches conflicts unless the ids returned by the query (one
// uint column, one bind arg) and the payload ids form the same set.
func checkIdSetMatches(ctx context.Context, tx *sqlx.Tx, query string, idUser uint64, payloadIds []uint) error {
	var storedIds []uint
	if err := tx.SelectContext(ctx, &storedIds, query, idUser); err != nil {
		return err
	}

	stored := make(map[uint]struct{}, len(storedIds))
	for _, id := range storedIds {
		stored[id] = struct{}{}
	}

	payload := make(map[uint]struct{}, len(payloadIds))
	for _, id := range payloadIds {
		if _, dup := payload[id]; dup {
			return apperror.NewConflict("migration", "duplicate id in payload")
		}
		if _, ok := stored[id]; !ok {
			return apperror.NewConflict("migration", "dataset changed, refetch and retry")
		}
		payload[id] = struct{}{}
	}

	if len(payload) != len(stored) {
		return apperror.NewConflict("migration", "dataset changed, refetch and retry")
	}
	return nil
}

func categoryIds(data *e2ee.MigrationData) []uint {
	ids := make([]uint, 0, len(data.Categories))
	for _, c := range data.Categories {
		ids = append(ids, c.Id)
	}
	return ids
}

func tagIds(data *e2ee.MigrationData) []uint {
	ids := make([]uint, 0, len(data.Tags))
	for _, t := range data.Tags {
		ids = append(ids, t.Id)
	}
	return ids
}

func eventIds(data *e2ee.MigrationData) []uint {
	ids := make([]uint, 0, len(data.Events))
	for _, ev := range data.Events {
		ids = append(ids, ev.Id)
	}
	return ids
}

func boolLabel(b bool) string {
	if b {
		return "true"
	}
	return "false"
}
