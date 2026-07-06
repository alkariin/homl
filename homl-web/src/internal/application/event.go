package application

import (
	"context"
	"sort"
	"strconv"
	"time"

	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
)

// EventsService is the use-case port of the Event aggregate.
type EventsService interface {
	GetEvents(ctx context.Context, idUser uint64, tags []string) ([]event.GetEventsResponse, error)
	CreateEvent(ctx context.Context, idUser uint64, e *event.Event, tagsId []uint) error
	UpdateEvent(ctx context.Context, idUser uint64, e *event.Event, tagsId []uint) error
	DeleteEvent(ctx context.Context, idEvent uint) error
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
	// Deduplicate the requested tags: the repository matches events against
	// ALL of them by counting distinct names, so duplicates would never match.
	var encTags []string
	seen := make(map[string]bool)
	for _, t := range tags {
		if seen[t] {
			continue
		}
		seen[t] = true

		encTag, err := e.Crypto.Encrypt(t)
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
		decDescription, err := e.Crypto.Decrypt(evt.Description)
		if err != nil {
			return nil, err
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
	tags, err := e.buildDateTags(ctx, idUser, event.Date)
	if err != nil {
		return err
	}

	return e.EventsRepository.CreateEventWithTags(ctx, tags, tagsId, event, idUser)
}

func (e *eventsService) UpdateEvent(ctx context.Context, idUser uint64, event *event.Event, tagsId []uint) error {
	tags, err := e.buildDateTags(ctx, idUser, event.Date)
	if err != nil {
		return err
	}

	return e.EventsRepository.UpdateEventWithTags(ctx, tags, tagsId, event, idUser)
}

// buildDateTags returns the month and year tags of the event's date, reusing
// the existing tag ids when the user already has them in his date category.
func (e *eventsService) buildDateTags(ctx context.Context, idUser uint64, date time.Time) ([]category.Tag, error) {
	idCategoryDate, err := e.CategoriesRepository.FindLastIdByIdUser(ctx, idUser)
	if err != nil {
		return nil, err
	}

	month := date.Month().String()
	year := strconv.Itoa(date.Year())

	var tags []category.Tag
	for _, name := range []string{month, year} {
		encName, err := e.Crypto.Encrypt(name)
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

func (e *eventsService) DeleteEvent(ctx context.Context, idEvent uint) error {
	return e.EventsRepository.Delete(ctx, idEvent)
}
