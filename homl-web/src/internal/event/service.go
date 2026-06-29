package event

import (
	"sort"
	"strconv"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/shared"
)

type eventsService struct {
	EventsRepository     domain.EventsRepository
	CategoriesRepository domain.CategoriesRepository
	TagsRepository       domain.TagsRepository
}

type ESConfig struct {
	EventsRepository     domain.EventsRepository
	CategoriesRepository domain.CategoriesRepository
	TagsRepository       domain.TagsRepository
}

func NewEventsService(c *ESConfig) domain.EventsService {
	return &eventsService{
		EventsRepository:     c.EventsRepository,
		CategoriesRepository: c.CategoriesRepository,
		TagsRepository:       c.TagsRepository,
	}
}

func (e *eventsService) GetEvents(idUser uint64, tags []string) ([]domain.GetEventsResponse, error) {
	var encTags []string
	for _, t := range tags {
		encTag, err := shared.Encrypt(t)
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

	var responses = make([]domain.GetEventsResponse, 0)
	for _, k := range keys {
		event := resEvents[uint(k)]
		decDescription, err := shared.Decrypt(event.Description)
		if err != nil {
			return nil, err
		}

		var response domain.GetEventsResponse
		response.Id = event.Id
		response.Description = decDescription
		response.Date = event.Date
		response.Tags = resTags[event.Id]
		responses = append(responses, response)
	}

	return responses, nil
}

func (e *eventsService) CreateEvent(idUser uint64, event *domain.Event, tagsId []uint) error {
	// create date with month/year tags
	idCategoryDate, err := e.CategoriesRepository.FindLastIdByIdUser(idUser)
	if err != nil {
		return err
	}

	month := event.Date.Month().String()
	encMonth, err := shared.Encrypt(month)
	if err != nil {
		return err
	}

	idTagMonth, err := e.TagsRepository.FindTagIdByTagAndIdCategory(encMonth, idCategoryDate)
	if err != nil {
		return err
	}

	var monthTag domain.Tag
	if idTagMonth == 0 {
		monthTag = domain.Tag{
			Tag:        month,
			IdCategory: idCategoryDate,
		}
	} else {
		monthTag = domain.Tag{
			Id: idTagMonth,
		}
	}

	year := strconv.Itoa(event.Date.Year())
	encYear, err := shared.Encrypt(year)
	if err != nil {
		return err
	}

	idTagYear, err := e.TagsRepository.FindTagIdByTagAndIdCategory(encYear, idCategoryDate)
	if err != nil {
		return err
	}

	var yearTag domain.Tag
	if idTagYear == 0 {
		yearTag = domain.Tag{
			Tag:        year,
			IdCategory: idCategoryDate,
		}
	} else {
		yearTag = domain.Tag{
			Id: idTagYear,
		}
	}
	var tags = []domain.Tag{}
	tags = append(tags, monthTag, yearTag)

	return e.EventsRepository.CreateEventWithTags(tags, tagsId, event, idUser)
}

func (e *eventsService) UpdateEvent(idUser uint64, event *domain.Event, tagsId []uint) error {
	// create date with month/year tags
	idCategoryDate, err := e.CategoriesRepository.FindLastIdByIdUser(idUser)
	if err != nil {
		return err
	}

	month := event.Date.Month().String()
	encMonth, err := shared.Encrypt(month)
	if err != nil {
		return err
	}

	idTagMonth, err := e.TagsRepository.FindTagIdByTagAndIdCategory(encMonth, idCategoryDate)
	if err != nil {
		return err
	}

	var monthTag domain.Tag
	if idTagMonth == 0 {
		monthTag = domain.Tag{
			Tag:        month,
			IdCategory: idCategoryDate,
		}
	} else {
		monthTag = domain.Tag{
			Id: idTagMonth,
		}
	}

	year := strconv.Itoa(event.Date.Year())
	encYear, err := shared.Encrypt(year)
	if err != nil {
		return err
	}

	idTagYear, err := e.TagsRepository.FindTagIdByTagAndIdCategory(encYear, idCategoryDate)
	if err != nil {
		return err
	}

	var yearTag domain.Tag
	if idTagYear == 0 {
		yearTag = domain.Tag{
			Tag:        year,
			IdCategory: idCategoryDate,
		}
	} else {
		yearTag = domain.Tag{
			Id: idTagYear,
		}
	}
	var tags = []domain.Tag{}
	tags = append(tags, monthTag, yearTag)

	return e.EventsRepository.UpdateEventWithTags(tags, tagsId, event, idUser)
}

func (e *eventsService) DeleteEvent(idEvent uint) error {
	return e.EventsRepository.Delete(idEvent)
}
