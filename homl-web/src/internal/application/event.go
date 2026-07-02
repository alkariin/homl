package application

import (
	"sort"
	"strconv"

	"github.com/alkariin/homl/homl-web/internal/crypto"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
	"github.com/alkariin/homl/homl-web/internal/domain/tag"
)

// EventsService is the use-case port of the Event aggregate.
type EventsService interface {
	GetEvents(idUser uint64, tags []string) ([]event.GetEventsResponse, error)
	CreateEvent(idUser uint64, e *event.Event, tagsId []uint) error
	UpdateEvent(idUser uint64, e *event.Event, tagsId []uint) error
	DeleteEvent(idEvent uint) error
}

type eventsService struct {
	EventsRepository     event.Repository
	CategoriesRepository category.Repository
	TagsRepository       tag.Repository
}

type ESConfig struct {
	EventsRepository     event.Repository
	CategoriesRepository category.Repository
	TagsRepository       tag.Repository
}

func NewEventsService(c *ESConfig) EventsService {
	return &eventsService{
		EventsRepository:     c.EventsRepository,
		CategoriesRepository: c.CategoriesRepository,
		TagsRepository:       c.TagsRepository,
	}
}

func (e *eventsService) GetEvents(idUser uint64, tags []string) ([]event.GetEventsResponse, error) {
	var encTags []string
	for _, t := range tags {
		encTag, err := crypto.Encrypt(t)
		if err != nil {
			return nil, err
		}
		encTags = append(encTags, encTag)
	}

	resEvents, resTags, err := e.EventsRepository.FindEventsWithTags(encTags, idUser)
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
		decDescription, err := crypto.Decrypt(evt.Description)
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

func (e *eventsService) CreateEvent(idUser uint64, event *event.Event, tagsId []uint) error {
	// create date with month/year tags
	idCategoryDate, err := e.CategoriesRepository.FindLastIdByIdUser(idUser)
	if err != nil {
		return err
	}

	month := event.Date.Month().String()
	encMonth, err := crypto.Encrypt(month)
	if err != nil {
		return err
	}

	idTagMonth, err := e.TagsRepository.FindTagIdByTagAndIdCategory(encMonth, idCategoryDate)
	if err != nil {
		return err
	}

	var monthTag tag.Tag
	if idTagMonth == 0 {
		monthTag = tag.Tag{
			Tag:        month,
			IdCategory: idCategoryDate,
		}
	} else {
		monthTag = tag.Tag{
			Id: idTagMonth,
		}
	}

	year := strconv.Itoa(event.Date.Year())
	encYear, err := crypto.Encrypt(year)
	if err != nil {
		return err
	}

	idTagYear, err := e.TagsRepository.FindTagIdByTagAndIdCategory(encYear, idCategoryDate)
	if err != nil {
		return err
	}

	var yearTag tag.Tag
	if idTagYear == 0 {
		yearTag = tag.Tag{
			Tag:        year,
			IdCategory: idCategoryDate,
		}
	} else {
		yearTag = tag.Tag{
			Id: idTagYear,
		}
	}
	var tags = []tag.Tag{}
	tags = append(tags, monthTag, yearTag)

	return e.EventsRepository.CreateEventWithTags(tags, tagsId, event, idUser)
}

func (e *eventsService) UpdateEvent(idUser uint64, event *event.Event, tagsId []uint) error {
	// create date with month/year tags
	idCategoryDate, err := e.CategoriesRepository.FindLastIdByIdUser(idUser)
	if err != nil {
		return err
	}

	month := event.Date.Month().String()
	encMonth, err := crypto.Encrypt(month)
	if err != nil {
		return err
	}

	idTagMonth, err := e.TagsRepository.FindTagIdByTagAndIdCategory(encMonth, idCategoryDate)
	if err != nil {
		return err
	}

	var monthTag tag.Tag
	if idTagMonth == 0 {
		monthTag = tag.Tag{
			Tag:        month,
			IdCategory: idCategoryDate,
		}
	} else {
		monthTag = tag.Tag{
			Id: idTagMonth,
		}
	}

	year := strconv.Itoa(event.Date.Year())
	encYear, err := crypto.Encrypt(year)
	if err != nil {
		return err
	}

	idTagYear, err := e.TagsRepository.FindTagIdByTagAndIdCategory(encYear, idCategoryDate)
	if err != nil {
		return err
	}

	var yearTag tag.Tag
	if idTagYear == 0 {
		yearTag = tag.Tag{
			Tag:        year,
			IdCategory: idCategoryDate,
		}
	} else {
		yearTag = tag.Tag{
			Id: idTagYear,
		}
	}
	var tags = []tag.Tag{}
	tags = append(tags, monthTag, yearTag)

	return e.EventsRepository.UpdateEventWithTags(tags, tagsId, event, idUser)
}

func (e *eventsService) DeleteEvent(idEvent uint) error {
	return e.EventsRepository.Delete(idEvent)
}
