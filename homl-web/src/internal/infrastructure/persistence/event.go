package persistence

import (
	"context"
	"database/sql"
	"strconv"
	"strings"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/crypto"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
	"github.com/alkariin/homl/homl-web/internal/domain/tag"
)

// nullStringToString converts a sql.NullString to a plain string (empty when NULL).
func nullStringToString(ns sql.NullString) string {
	if ns.Valid {
		return ns.String
	}
	return ""
}

type EventsRepository struct {
	DB *sql.DB
}

func NewEventsRepository(db *sql.DB) event.Repository {
	return &EventsRepository{
		DB: db,
	}
}

func (e *EventsRepository) FindEventsWithTags(encTags []string, idUser uint64) (map[uint]event.Event, map[uint][]tag.Tag, error) {
	var tagsQuery string
	if len(encTags) == 0 {
		tagsQuery = ""
	} else {
		tagsAsString := "\"" + strings.Join(encTags, "\", \"") + "\""
		tagsQuery = ` AND Tags.tag IN (` + tagsAsString + `)`
	}
	uId := strconv.Itoa(int(idUser))
	query := `
		SELECT Events.id, Events.description, Events.date, Tags.id, Tags.tag, Tags.idCategory
			FROM Tags INNER JOIN Events INNER JOIN
			(
				SELECT DISTINCT idTag, idEvent
				FROM EventsTags
				WHERE idUser = ` + uId + `
				AND idEvent IN (
					SELECT DISTINCT Events.id as SelectedEventId
					FROM Events
					INNER JOIN EventsTags ON Events.id = EventsTags.idEvent
					INNER JOIN Tags ON  EventsTags.idTag = Tags.id
					WHERE EventsTags.idUser = ` + uId + tagsQuery + `
				)
			) as ETags
		ON Tags.id = ETags.idTag
		AND Events.id = ETags.idEvent
		ORDER BY Events.id, Tags.id;
	`

	results, err := e.DB.Query(query)
	if err != nil {
		return nil, nil, err
	}

	resTags := make(map[uint][]tag.Tag)
	resEvents := make(map[uint]event.Event)
	for results.Next() {
		var tag tag.Tag
		var event event.Event
		var description sql.NullString
		err = results.Scan(&event.Id, &description, &event.Date, &tag.Id, &tag.Tag, &tag.IdCategory)
		if err != nil {
			return nil, nil, err
		}
		event.Description = nullStringToString(description)

		decTag, err := crypto.Decrypt(tag.Tag)
		if err != nil {
			return nil, nil, err
		}

		tag.Tag = decTag
		resTags[event.Id] = append(resTags[event.Id], tag)
		resEvents[event.Id] = event
	}

	return resEvents, resTags, nil
}

func (e *EventsRepository) CreateEventWithTags(tags []tag.Tag, tagsId []uint, event *event.Event, idUser uint64) error {
	ctx := context.Background()
	tx, err := e.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	otherTagsId, err := CreateAllTags(ctx, tx, tags)
	if err != nil {
		return err
	}
	tagsId = append(tagsId, otherTagsId...)

	// it works even if the description has been omitted
	encDescription, err := crypto.Encrypt(event.Description)
	if err != nil {
		tx.Rollback()
		return err
	}

	_, err = tx.ExecContext(ctx, "INSERT INTO Events (description, date) VALUES (?, ?);", encDescription, event.Date)
	if err != nil {
		tx.Rollback()
		return err
	}

	row := tx.QueryRow("SELECT LAST_INSERT_ID();")
	var eventId uint
	err = row.Scan(&eventId)
	if err != nil {
		tx.Rollback()
		return err
	}

	for _, tagId := range tagsId {
		_, err = tx.ExecContext(ctx, "INSERT INTO EventsTags (idTag, idEvent, idUser) VALUES (?, ?, ?)", tagId, eventId, idUser)
		if err != nil {
			tx.Rollback()
			return err
		}
	}

	return tx.Commit()
}

func (e *EventsRepository) UpdateEventWithTags(tags []tag.Tag, tagsId []uint, event *event.Event, idUser uint64) error {
	ctx := context.Background()
	tx, err := e.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	otherTagsId, err := CreateAllTags(ctx, tx, tags)
	if err != nil {
		return err
	}
	tagsId = append(tagsId, otherTagsId...)

	encDescription, err := crypto.Encrypt(event.Description)
	if err != nil {
		tx.Rollback()
		return err
	}

	_, err = tx.ExecContext(ctx, "UPDATE Events SET description = ?, date = ? WHERE id = ?", encDescription, event.Date, event.Id)
	if err != nil {
		tx.Rollback()
		return err
	}

	// clean EventsTags before inserting the new ones
	_, err = tx.ExecContext(ctx, "DELETE FROM EventsTags WHERE idUser = ? AND idEvent = ?;", idUser, event.Id)
	if err != nil {
		tx.Rollback()
		return err
	}

	for _, tagId := range tagsId {
		_, err = tx.ExecContext(ctx, "INSERT INTO EventsTags (idTag, idEvent, idUser) VALUES (?, ?, ?)", tagId, event.Id, idUser)
		if err != nil {
			tx.Rollback()
			return err
		}
	}

	return tx.Commit()
}

func (e *EventsRepository) Delete(id uint) error {
	res, err := e.DB.Exec("DELETE FROM Events WHERE id = ?", id)
	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	return nil
}
