package service

import (
	"sort"
	"strconv"

	"github.com/alkariin/homl/homl-web/helper"
	"github.com/alkariin/homl/homl-web/model"
)

type eventsService struct {
	EventsRepository     model.EventsRepository
	CategoriesRepository model.CategoriesRepository
	TagsRepository       model.TagsRepository
}

type ESConfig struct {
	EventsRepository     model.EventsRepository
	CategoriesRepository model.CategoriesRepository
	TagsRepository       model.TagsRepository
}

func NewEventsService(c *ESConfig) model.EventsService {
	return &eventsService{
		EventsRepository:     c.EventsRepository,
		CategoriesRepository: c.CategoriesRepository,
		TagsRepository:       c.TagsRepository,
	}
}

func (e *eventsService) GetEvents(idUser uint64, tags []string) ([]model.GetEventsResponse, error) {
	var encTags []string
	for _, t := range tags {
		encTag, err := helper.Encrypt(t)
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

	var responses = make([]model.GetEventsResponse, 0)
	for _, k := range keys {
		event := resEvents[uint(k)]
		decDescription, err := helper.Decrypt(event.Description)
		if err != nil {
			return nil, err
		}

		var response model.GetEventsResponse
		response.Id = event.Id
		response.Description = decDescription
		response.Date = event.Date
		response.Tags = resTags[event.Id]
		responses = append(responses, response)
	}

	return responses, nil
}

func (e *eventsService) CreateEvent(idUser uint64, event *model.Event, tagsId []uint) error {
	// create date with month/year tags
	idCategoryDate, err := e.CategoriesRepository.FindLastIdByIdUser(idUser)
	if err != nil {
		return err
	}

	month := event.Date.Month().String()
	encMonth, err := helper.Encrypt(month)
	if err != nil {
		return err
	}

	idTagMonth, err := e.TagsRepository.FindTagIdByTagAndIdCategory(encMonth, idCategoryDate)
	if err != nil {
		return err
	}

	var monthTag model.Tag
	if idTagMonth == 0 {
		monthTag = model.Tag{
			Tag:        month,
			IdCategory: idCategoryDate,
		}
	} else {
		monthTag = model.Tag{
			Id: idTagMonth,
		}
	}

	year := strconv.Itoa(event.Date.Year())
	encYear, err := helper.Encrypt(year)
	if err != nil {
		return err
	}

	idTagYear, err := e.TagsRepository.FindTagIdByTagAndIdCategory(encYear, idCategoryDate)
	if err != nil {
		return err
	}

	var yearTag model.Tag
	if idTagYear == 0 {
		yearTag = model.Tag{
			Tag:        year,
			IdCategory: idCategoryDate,
		}
	} else {
		yearTag = model.Tag{
			Id: idTagYear,
		}
	}
	var tags = []model.Tag{}
	tags = append(tags, monthTag, yearTag)

	return e.EventsRepository.CreateEventWithTags(tags, tagsId, event, idUser)
}

func (e *eventsService) UpdateEvent(idUser uint64, event *model.Event, tagsId []uint) error {
	// create date with month/year tags
	idCategoryDate, err := e.CategoriesRepository.FindLastIdByIdUser(idUser)
	if err != nil {
		return err
	}

	month := event.Date.Month().String()
	encMonth, err := helper.Encrypt(month)
	if err != nil {
		return err
	}

	idTagMonth, err := e.TagsRepository.FindTagIdByTagAndIdCategory(encMonth, idCategoryDate)
	if err != nil {
		return err
	}

	var monthTag model.Tag
	if idTagMonth == 0 {
		monthTag = model.Tag{
			Tag:        month,
			IdCategory: idCategoryDate,
		}
	} else {
		monthTag = model.Tag{
			Id: idTagMonth,
		}
	}

	year := strconv.Itoa(event.Date.Year())
	encYear, err := helper.Encrypt(year)
	if err != nil {
		return err
	}

	idTagYear, err := e.TagsRepository.FindTagIdByTagAndIdCategory(encYear, idCategoryDate)
	if err != nil {
		return err
	}

	var yearTag model.Tag
	if idTagYear == 0 {
		yearTag = model.Tag{
			Tag:        year,
			IdCategory: idCategoryDate,
		}
	} else {
		yearTag = model.Tag{
			Id: idTagYear,
		}
	}
	var tags = []model.Tag{}
	tags = append(tags, monthTag, yearTag)

	return e.EventsRepository.UpdateEventWithTags(tags, tagsId, event, idUser)
}

func (e *eventsService) DeleteEvent(idEvent uint) error {
	return e.EventsRepository.Delete(idEvent)
}
