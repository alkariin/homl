// Package event holds the Event aggregate: entities, DTOs and the persistence port.
package event

import (
	"time"

	"github.com/alkariin/homl/homl-web/internal/domain/tag"
)

type Event struct {
	Id          uint      `json:"id"`
	Description string    `json:"description"`
	Date        time.Time `json:"date"` // type date doesn't exist in go
}

type GetEventsResponse struct {
	Event
	Tags []tag.Tag `json:"tags"`
}

// Repository is the persistence port of the Event aggregate.
type Repository interface {
	FindEventsWithTags(encTags []string, idUser uint64) (map[uint]Event, map[uint][]tag.Tag, error)
	CreateEventWithTags(tags []tag.Tag, tagsId []uint, event *Event, idUser uint64) error
	UpdateEventWithTags(tags []tag.Tag, tagsId []uint, event *Event, idUser uint64) error
	Delete(id uint) error
}
