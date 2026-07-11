// Package event holds the Event aggregate: entities, DTOs and the persistence port.
package event

import (
	"context"
	"time"

	"github.com/alkariin/homl/homl-web/internal/domain/category"
)

type Event struct {
	Id          uint      `json:"id" db:"id"`
	Description string    `json:"description" db:"description"`
	Date        time.Time `json:"date" db:"date"` // type date doesn't exist in go
}

type GetEventsResponse struct {
	Event
	Tags []category.Tag `json:"tags"`
}

// Repository is the persistence port of the Event aggregate. Every method is
// scoped to the owning user.
type Repository interface {
	FindEventsWithTags(ctx context.Context, encTags []string, idUser uint64) (map[uint]Event, map[uint][]category.Tag, error)
	CreateEventWithTags(ctx context.Context, tags []category.Tag, tagsId []uint, event *Event, idUser uint64) error
	UpdateEventWithTags(ctx context.Context, tags []category.Tag, tagsId []uint, event *Event, idUser uint64) error
	Delete(ctx context.Context, id uint, idUser uint64) error
}
