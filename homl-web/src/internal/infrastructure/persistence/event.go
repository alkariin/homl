package persistence

import (
	"context"
	"database/sql"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
	"github.com/jmoiron/sqlx"
)

// nullStringToString converts a sql.NullString to a plain string (empty when NULL).
func nullStringToString(ns sql.NullString) string {
	if ns.Valid {
		return ns.String
	}
	return ""
}

type EventsRepository struct {
	DB     *sqlx.DB
	Crypto application.Encryptor
}

func NewEventsRepository(db *sqlx.DB, crypto application.Encryptor) event.Repository {
	return &EventsRepository{
		DB:     db,
		Crypto: crypto,
	}
}

// FindEventsWithTags returns the user's events with all their tags. When
// encTags is provided, only events matching ALL the given tag names are
// returned; a name matches through its whole synonym group (main tag +
// synonyms, resolved via COALESCE(idParentTag, id) as the group root).
func (e *EventsRepository) FindEventsWithTags(ctx context.Context, encTags []string, idUser uint64) (map[uint]event.Event, map[uint][]category.Tag, error) {
	var filterClause string
	if len(encTags) > 0 {
		// The Categories.idUser filter on the named tags is mandatory:
		// encryption is deterministic, so without it another user's
		// identically-named tag could leak matches.
		filterClause = `
				AND idEvent IN (
					SELECT ET.idEvent
					FROM EventsTags ET
					INNER JOIN Tags evtTag ON evtTag.id = ET.idTag
					INNER JOIN Tags named
						ON COALESCE(named.idParentTag, named.id) = COALESCE(evtTag.idParentTag, evtTag.id)
					INNER JOIN Categories c ON named.idCategory = c.id
					WHERE ET.idUser = ?
					AND c.idUser = ?
					AND named.tag IN (?)
					GROUP BY ET.idEvent
					HAVING COUNT(DISTINCT named.tag) = ?
				)`
	}
	query := `
		SELECT Events.id, Events.description, Events.date, Tags.id, Tags.tag, Tags.idCategory, Tags.idParentTag
			FROM Tags INNER JOIN Events INNER JOIN
			(
				SELECT DISTINCT idTag, idEvent
				FROM EventsTags
				WHERE idUser = ?` + filterClause + `
			) as ETags
		ON Tags.id = ETags.idTag
		AND Events.id = ETags.idEvent
		ORDER BY Events.id, Tags.id;
	`

	args := []interface{}{idUser}
	if len(encTags) > 0 {
		var err error
		query, args, err = sqlx.In(query, idUser, idUser, idUser, encTags, len(encTags))
		if err != nil {
			return nil, nil, err
		}
	}

	results, err := e.DB.QueryxContext(ctx, e.DB.Rebind(query), args...)
	if err != nil {
		return nil, nil, err
	}
	defer results.Close()

	resTags := make(map[uint][]category.Tag)
	resEvents := make(map[uint]event.Event)
	for results.Next() {
		var tag category.Tag
		var event event.Event
		var description sql.NullString
		err = results.Scan(&event.Id, &description, &event.Date, &tag.Id, &tag.Tag, &tag.IdCategory, &tag.IdParentTag)
		if err != nil {
			return nil, nil, err
		}
		event.Description = nullStringToString(description)

		decTag, err := e.Crypto.Decrypt(tag.Tag)
		if err != nil {
			return nil, nil, err
		}

		tag.Tag = decTag
		resTags[event.Id] = append(resTags[event.Id], tag)
		resEvents[event.Id] = event
	}
	if err := results.Err(); err != nil {
		return nil, nil, err
	}

	return resEvents, resTags, nil
}

func (e *EventsRepository) CreateEventWithTags(ctx context.Context, tags []category.Tag, tagsId []uint, event *event.Event, idUser uint64) error {
	tx, err := e.DB.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	otherTagsId, err := CreateAllTags(ctx, tx, e.Crypto, tags)
	if err != nil {
		return err
	}
	tagsId = append(tagsId, otherTagsId...)

	// it works even if the description has been omitted
	encDescription, err := e.Crypto.Encrypt(event.Description)
	if err != nil {
		return err
	}

	res, err := tx.ExecContext(ctx, "INSERT INTO Events (description, date) VALUES (?, ?);", encDescription, event.Date)
	if err != nil {
		return err
	}

	eventId, err := res.LastInsertId()
	if err != nil {
		return err
	}

	for _, tagId := range tagsId {
		_, err = tx.ExecContext(ctx, "INSERT INTO EventsTags (idTag, idEvent, idUser) VALUES (?, ?, ?)", tagId, eventId, idUser)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (e *EventsRepository) UpdateEventWithTags(ctx context.Context, tags []category.Tag, tagsId []uint, event *event.Event, idUser uint64) error {
	tx, err := e.DB.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	otherTagsId, err := CreateAllTags(ctx, tx, e.Crypto, tags)
	if err != nil {
		return err
	}
	tagsId = append(tagsId, otherTagsId...)

	encDescription, err := e.Crypto.Encrypt(event.Description)
	if err != nil {
		return err
	}

	_, err = tx.ExecContext(ctx, "UPDATE Events SET description = ?, date = ? WHERE id = ?", encDescription, event.Date, event.Id)
	if err != nil {
		return err
	}

	// clean EventsTags before inserting the new ones
	_, err = tx.ExecContext(ctx, "DELETE FROM EventsTags WHERE idUser = ? AND idEvent = ?;", idUser, event.Id)
	if err != nil {
		return err
	}

	for _, tagId := range tagsId {
		_, err = tx.ExecContext(ctx, "INSERT INTO EventsTags (idTag, idEvent, idUser) VALUES (?, ?, ?)", tagId, event.Id, idUser)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (e *EventsRepository) Delete(ctx context.Context, id uint) error {
	res, err := e.DB.ExecContext(ctx, "DELETE FROM Events WHERE id = ?", id)
	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	return nil
}
