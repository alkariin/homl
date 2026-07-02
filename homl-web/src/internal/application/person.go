package application

import (
	"sort"
	"strings"

	"github.com/alkariin/homl/homl-web/internal/crypto"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/person"
	"github.com/alkariin/homl/homl-web/internal/domain/tag"
)

// PersonsService is the use-case port of the Person aggregate.
type PersonsService interface {
	GetPersons(idUser uint64) ([]person.GetPersonsResponse, error)
	CreatePerson(p *person.Person, nicknames []string, idUser uint64) error
	UpdatePerson(p *person.Person, nicknames []person.Nickname, idUser uint64) error
	DeletePerson(idPerson uint, idUser uint64) error
}

type personsService struct {
	PersonsRepository    person.Repository
	CategoriesRepository category.Repository
	TagsRepository       tag.Repository
}

type PSConfig struct {
	PersonsRepository    person.Repository
	CategoriesRepository category.Repository
	TagsRepository       tag.Repository
}

func NewPersonsService(c *PSConfig) PersonsService {
	return &personsService{
		PersonsRepository:    c.PersonsRepository,
		CategoriesRepository: c.CategoriesRepository,
		TagsRepository:       c.TagsRepository,
	}
}

func (s *personsService) GetPersons(idUser uint64) ([]person.GetPersonsResponse, error) {
	persons, nicknames, err := s.PersonsRepository.FindPersonsWithTagsAndCategories(idUser)
	if err != nil {
		return nil, err
	}

	keys := make([]int, 0)
	for k := range persons {
		keys = append(keys, int(k))
	}
	sort.Ints(keys)

	var responses = make([]person.GetPersonsResponse, 0)
	for _, k := range keys {
		p := persons[uint(k)]
		decFirstname, err := crypto.Decrypt(p.Firstname)
		if err != nil {
			return nil, err
		}

		decLastname, err := crypto.Decrypt(p.Lastname)
		if err != nil {
			return nil, err
		}

		var response person.GetPersonsResponse
		response.Id = p.Id
		response.Firstname = decFirstname
		response.Lastname = decLastname
		response.Nicknames = nicknames[p.Id]
		responses = append(responses, response)
	}

	return responses, nil
}

func (s *personsService) CreatePerson(person *person.Person, nicknames []string, idUser uint64) error {
	firstname := strings.Title(person.Firstname)
	lastname := strings.Title(person.Lastname)
	encFirstname, err := crypto.Encrypt(firstname)
	if err != nil {
		return err
	}
	encLastname, err := crypto.Encrypt(lastname)
	if err != nil {
		return err
	}

	mainTagName := firstname + lastname
	encMainTagName, err := crypto.Encrypt(mainTagName)
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

func (s *personsService) UpdatePerson(person *person.Person, nicknames []person.Nickname, idUser uint64) error {
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
	encFirstname, err := crypto.Encrypt(firstname)
	if err != nil {
		return err
	}
	encLastname, err := crypto.Encrypt(lastname)
	if err != nil {
		return err
	}

	mainTagName := firstname + lastname
	encMainTagName, err := crypto.Encrypt(mainTagName)
	if err != nil {
		return err
	}

	return s.PersonsRepository.UpdatePersonWithTags(storedPerson, encFirstname, encLastname, encMainTagName, mainPersonTagId, idCategoryPerson, idUser, nicknames)
}

func (s *personsService) DeletePerson(idPerson uint, idUser uint64) error {
	return s.PersonsRepository.DeletePerson(idPerson, idUser)
}
