package application

import (
	"context"
	"sort"
	"strconv"
	"time"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/e2ee"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
)

// EventsService is the use-case port of the Event aggregate.
type EventsService interface {
	GetEvents(ctx context.Context, idUser uint64, tags []string) ([]event.GetEventsResponse, error)
	CreateEvent(ctx context.Context, idUser uint64, e *event.Event, tagsId []uint) error
	UpdateEvent(ctx context.Context, idUser uint64, e *event.Event, tagsId []uint) error
	DeleteEvent(ctx context.Context, idEvent uint, idUser uint64) error
}

type eventsService struct {
	EventsRepository     event.Repository
	CategoriesRepository category.Repository
	Crypto               Encryptor
}

type ESConfig struct {
	EventsRepository     event.Repository
	CategoriesRepository category.Repository
	Crypto               Encryptor
}

func NewEventsService(c *ESConfig) EventsService {
	return &eventsService{
		EventsRepository:     c.EventsRepository,
		CategoriesRepository: c.CategoriesRepository,
		Crypto:               c.Crypto,
	}
}

func (e *eventsService) GetEvents(ctx context.Context, idUser uint64, tags []string) ([]event.GetEventsResponse, error) {
	isE2ee := e2ee.Enabled(ctx)

	// Deduplicate the requested tags: the repository matches events against
	// ALL of them by counting distinct names, so duplicates would never match.
	var encTags []string
	seen := make(map[string]bool)
	for _, t := range tags {
		if isE2ee {
			// E2EE clients search by blind index; the values must not be
			// normalized or encrypted server-side.
			if !e2ee.IsIndex(t) {
				return nil, apperror.NewBadRequest("The given tags filter is not valid")
			}
		} else {
			// Tags are stored title-cased (see validateTag): normalize the
			// search term the same way or the deterministic ciphertexts never
			// match.
			t = titleCase(t)
		}
		if seen[t] {
			continue
		}
		seen[t] = true

		if isE2ee {
			encTags = append(encTags, t)
			continue
		}
		encTag, err := e.Crypto.Encrypt(t, idUser)
		if err != nil {
			return nil, err
		}
		encTags = append(encTags, encTag)
	}

	resEvents, resTags, err := e.EventsRepository.FindEventsWithTags(ctx, encTags, idUser)
	if err != nil {
		return nil, err
	}

	keys := make([]int, 0)
	for k, _ := range resEvents {
		keys = append(keys, int(k))
	}
	sort.Ints(keys)

	var responses = make([]event.GetEventsResponse, 0)
	for _, k := range keys {
		evt := resEvents[uint(k)]
		// E2EE descriptions are opaque blobs returned verbatim; only the
		// client can decrypt them.
		decDescription := evt.Description
		if !isE2ee {
			decDescription, err = e.Crypto.Decrypt(evt.Description, idUser)
			if err != nil {
				return nil, err
			}
		}

		var response event.GetEventsResponse
		response.Id = evt.Id
		response.Description = decDescription
		response.Date = evt.Date
		response.Tags = resTags[evt.Id]
		responses = append(responses, response)
	}

	return responses, nil
}

func (e *eventsService) CreateEvent(ctx context.Context, idUser uint64, event *event.Event, tagsId []uint) error {
	// The tag ids come straight from the client: refuse any that live in
	// another user's categories.
	if err := e.CategoriesRepository.CheckTagsBelongToUser(ctx, tagsId, idUser); err != nil {
		return err
	}

	tags, err := e.prepareEvent(ctx, idUser, event)
	if err != nil {
		return err
	}

	return e.EventsRepository.CreateEventWithTags(ctx, tags, tagsId, event, idUser)
}

func (e *eventsService) UpdateEvent(ctx context.Context, idUser uint64, event *event.Event, tagsId []uint) error {
	if err := e.CategoriesRepository.CheckTagsBelongToUser(ctx, tagsId, idUser); err != nil {
		return err
	}

	tags, err := e.prepareEvent(ctx, idUser, event)
	if err != nil {
		return err
	}

	return e.EventsRepository.UpdateEventWithTags(ctx, tags, tagsId, event, idUser)
}

// prepareEvent runs the mode-specific write checks shared by CreateEvent and
// UpdateEvent and returns the backend-managed tags to attach. E2EE clients
// send an encrypted description and manage their own date tags, so there is
// nothing to build for them.
func (e *eventsService) prepareEvent(ctx context.Context, idUser uint64, event *event.Event) ([]category.Tag, error) {
	if e2ee.Enabled(ctx) {
		if event.Description != "" && !e2ee.IsBlob(event.Description) {
			return nil, apperror.NewBadRequest("The given description is not a valid encrypted payload")
		}
		return nil, nil
	}

	return e.buildDateTags(ctx, idUser, event.Date)
}

// buildDateTags returns the month and year tags of the event's date, reusing
// the existing tag ids when the user already has them in his date category.
func (e *eventsService) buildDateTags(ctx context.Context, idUser uint64, date time.Time) ([]category.Tag, error) {
	idCategoryDate, err := e.CategoriesRepository.FindIdByKind(ctx, idUser, category.KindDate)
	if err != nil {
		return nil, err
	}

	month := date.Month().String()
	year := strconv.Itoa(date.Year())

	var tags []category.Tag
	for _, name := range []string{month, year} {
		encName, err := e.Crypto.Encrypt(name, idUser)
		if err != nil {
			return nil, err
		}

		idTag, err := e.CategoriesRepository.FindTagIdByTagAndIdCategory(ctx, encName, idCategoryDate)
		if err != nil {
			return nil, err
		}

		if idTag == 0 {
			tags = append(tags, category.Tag{Tag: name, IdCategory: idCategoryDate})
		} else {
			tags = append(tags, category.Tag{Id: idTag})
		}
	}

	return tags, nil
}

func (e *eventsService) DeleteEvent(ctx context.Context, idEvent uint, idUser uint64) error {
	return e.EventsRepository.Delete(ctx, idEvent, idUser)
}
