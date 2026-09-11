// Package event holds the Event aggregate: entities, DTOs and the persistence port.
package event

import (
	"context"
	"strconv"
	"time"

	"github.com/alkariin/homl/homl-web/internal/domain/category"
)

// OngoingTag is the backend-managed date tag attached to every open period,
// so "what is going on right now" is one filter away. Stored in English for
// every user like the month names, and reserved (masterdata BLACKLIST_TAGS).
const OngoingTag = "Ongoing"

// Event is a single calendar day, a closed period or an open one:
//
//	single day     Date set, EndDate nil, IsOngoing false
//	closed period  Date set, EndDate set (inclusive, on or after Date)
//	open period    Date set, EndDate nil, IsOngoing true
//
// The application layer enforces the combinations (validatePeriod).
type Event struct {
	Id          uint      `json:"id" db:"id"`
	Description string    `json:"description" db:"description"`
	Date        time.Time `json:"date" db:"date"` // type date doesn't exist in go
	// EndDate is the inclusive last day of a closed period; nil for a single
	// day and for an open period.
	EndDate *time.Time `json:"endDate" db:"endDate"`
	// IsOngoing marks an open period: started on Date, no end yet.
	IsOngoing bool `json:"isOngoing" db:"isOngoing"`
}

// DateTagNames returns the names of the date tags the event's period implies:
// the English month name and the year of every month it is known to cover,
// plus OngoingTag for an open period. An open period has no known end, so it
// is tagged from its start month only — expanding to "today" at write time
// would bake in an answer that goes stale the next day and only ever grows
// when the event happens to be edited.
//
// The result is a set: the order carries no meaning (EventsTags has none).
// It assumes a validated event (EndDate on or after Date).
func (e *Event) DateTagNames() []string {
	end := e.Date
	if e.EndDate != nil {
		end = *e.EndDate
	}

	var names []string
	seen := make(map[string]bool)
	add := func(name string) {
		if !seen[name] {
			seen[name] = true
			names = append(names, name)
		}
	}

	// Walk month by month. Both bounds are pinned to the first of their month
	// so the loop needs no day-of-month arithmetic (a month added to
	// 31 January would otherwise land in March and skip February).
	cursor := time.Date(e.Date.Year(), e.Date.Month(), 1, 0, 0, 0, 0, time.UTC)
	last := time.Date(end.Year(), end.Month(), 1, 0, 0, 0, 0, time.UTC)
	for !cursor.After(last) {
		add(cursor.Month().String())
		add(strconv.Itoa(cursor.Year()))
		cursor = cursor.AddDate(0, 1, 0)
	}

	if e.IsOngoing {
		add(OngoingTag)
	}

	return names
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
