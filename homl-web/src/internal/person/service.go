package person

import (
	"sort"
	"strings"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/shared"
)

type personsService struct {
	PersonsRepository    domain.PersonsRepository
	CategoriesRepository domain.CategoriesRepository
	TagsRepository       domain.TagsRepository
}

type PSConfig struct {
	PersonsRepository    domain.PersonsRepository
	CategoriesRepository domain.CategoriesRepository
	TagsRepository       domain.TagsRepository
}

func NewPersonsService(c *PSConfig) domain.PersonsService {
	return &personsService{
		PersonsRepository:    c.PersonsRepository,
		CategoriesRepository: c.CategoriesRepository,
		TagsRepository:       c.TagsRepository,
	}
}

func (s *personsService) GetPersons(idUser uint64) ([]domain.GetPersonsResponse, error) {
	persons, nicknames, err := s.PersonsRepository.FindPersonsWithTagsAndCategories(idUser)
	if err != nil {
		return nil, err
	}

	keys := make([]int, 0)
	for k := range persons {
		keys = append(keys, int(k))
	}
	sort.Ints(keys)

	var responses = make([]domain.GetPersonsResponse, 0)
	for _, k := range keys {
		person := persons[uint(k)]
		decFirstname, err := shared.Decrypt(person.Firstname)
		if err != nil {
			return nil, err
		}

		decLastname, err := shared.Decrypt(person.Lastname)
		if err != nil {
			return nil, err
		}

		var response domain.GetPersonsResponse
		response.Id = person.Id
		response.Firstname = decFirstname
		response.Lastname = decLastname
		response.Nicknames = nicknames[person.Id]
		responses = append(responses, response)
	}

	return responses, nil
}

func (s *personsService) CreatePerson(person *domain.Person, nicknames []string, idUser uint64) error {
	firstname := strings.Title(person.Firstname)
	lastname := strings.Title(person.Lastname)
	encFirstname, err := shared.Encrypt(firstname)
	if err != nil {
		return err
	}
	encLastname, err := shared.Encrypt(lastname)
	if err != nil {
		return err
	}

	mainTagName := firstname + lastname
	encMainTagName, err := shared.Encrypt(mainTagName)
	if err != nil {
		return err
	}

	// Get idCategoryPerson
	idCategoryDate, err := s.CategoriesRepository.FindLastIdByIdUser(idUser)
	if err != nil {
		return err
	}
	idCategoryPerson := idCategoryDate + 1

	return s.PersonsRepository.CreatePersonWithTags(encFirstname, encLastname, encMainTagName, idCategoryPerson, nicknames)
}

func (s *personsService) UpdatePerson(person *domain.Person, nicknames []domain.Nickname, idUser uint64) error {
	// Get idCategoryPerson
	idCategoryDate, err := s.CategoriesRepository.FindLastIdByIdUser(idUser)
	if err != nil {
		return err
	}
	idCategoryPerson := idCategoryDate + 1

	// Verify if the given id is a person of the user
	err = s.PersonsRepository.CheckPersonIdsWithTagsAndCategories(idUser, person.Id)
	if err != nil {
		return err
	}

	// Get main tag of the person (used multiple times)
	mainPersonTagId, err := s.TagsRepository.FindMainTagIdOfPerson(person.Id)
	if err != nil {
		return err
	}

	// if first/lastname are updated the main tag should be updated as well
	storedPerson, err := s.PersonsRepository.FindById(person.Id)
	if err != nil {
		return err
	}

	firstname := strings.Title(person.Firstname)
	lastname := strings.Title(person.Lastname)
	encFirstname, err := shared.Encrypt(firstname)
	if err != nil {
		return err
	}
	encLastname, err := shared.Encrypt(lastname)
	if err != nil {
		return err
	}

	mainTagName := firstname + lastname
	encMainTagName, err := shared.Encrypt(mainTagName)
	if err != nil {
		return err
	}

	return s.PersonsRepository.UpdatePersonWithTags(storedPerson, encFirstname, encLastname, encMainTagName, mainPersonTagId, idCategoryPerson, idUser, nicknames)
}

func (s *personsService) DeletePerson(idPerson uint, idUser uint64) error {
	return s.PersonsRepository.DeletePerson(idPerson, idUser)
}
