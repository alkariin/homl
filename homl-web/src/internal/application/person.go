package application

import (
	"context"
	"sort"
	"strings"

	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/person"
)

// PersonsService is the use-case port of the Person aggregate.
type PersonsService interface {
	GetPersons(ctx context.Context, idUser uint64) ([]person.GetPersonsResponse, error)
	CreatePerson(ctx context.Context, p *person.Person, nicknames []string, idUser uint64) error
	UpdatePerson(ctx context.Context, p *person.Person, nicknames []person.Nickname, idUser uint64) error
	DeletePerson(ctx context.Context, idPerson uint, idUser uint64) error
}

type personsService struct {
	PersonsRepository    person.Repository
	CategoriesRepository category.Repository
	Crypto               Encryptor
}

type PSConfig struct {
	PersonsRepository    person.Repository
	CategoriesRepository category.Repository
	Crypto               Encryptor
}

func NewPersonsService(c *PSConfig) PersonsService {
	return &personsService{
		PersonsRepository:    c.PersonsRepository,
		CategoriesRepository: c.CategoriesRepository,
		Crypto:               c.Crypto,
	}
}

func (s *personsService) GetPersons(ctx context.Context, idUser uint64) ([]person.GetPersonsResponse, error) {
	persons, nicknames, err := s.PersonsRepository.FindPersonsWithTagsAndCategories(ctx, idUser)
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
		decFirstname, err := s.Crypto.Decrypt(p.Firstname)
		if err != nil {
			return nil, err
		}

		decLastname, err := s.Crypto.Decrypt(p.Lastname)
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

func (s *personsService) CreatePerson(ctx context.Context, person *person.Person, nicknames []string, idUser uint64) error {
	firstname := strings.Title(person.Firstname)
	lastname := strings.Title(person.Lastname)
	encFirstname, err := s.Crypto.Encrypt(firstname)
	if err != nil {
		return err
	}
	encLastname, err := s.Crypto.Encrypt(lastname)
	if err != nil {
		return err
	}

	mainTagName := firstname + lastname
	encMainTagName, err := s.Crypto.Encrypt(mainTagName)
	if err != nil {
		return err
	}

	idCategoryPerson, err := s.CategoriesRepository.FindIdByKind(ctx, idUser, category.KindPerson)
	if err != nil {
		return err
	}

	return s.PersonsRepository.CreatePersonWithTags(ctx, encFirstname, encLastname, encMainTagName, idCategoryPerson, nicknames)
}

func (s *personsService) UpdatePerson(ctx context.Context, person *person.Person, nicknames []person.Nickname, idUser uint64) error {
	idCategoryPerson, err := s.CategoriesRepository.FindIdByKind(ctx, idUser, category.KindPerson)
	if err != nil {
		return err
	}

	// Verify if the given id is a person of the user
	err = s.PersonsRepository.CheckPersonIdsWithTagsAndCategories(ctx, idUser, person.Id)
	if err != nil {
		return err
	}

	// Get main tag of the person (used multiple times)
	mainPersonTagId, err := s.CategoriesRepository.FindMainTagIdOfPerson(ctx, person.Id)
	if err != nil {
		return err
	}

	// if first/lastname are updated the main tag should be updated as well
	storedPerson, err := s.PersonsRepository.FindById(ctx, person.Id)
	if err != nil {
		return err
	}

	firstname := strings.Title(person.Firstname)
	lastname := strings.Title(person.Lastname)
	encFirstname, err := s.Crypto.Encrypt(firstname)
	if err != nil {
		return err
	}
	encLastname, err := s.Crypto.Encrypt(lastname)
	if err != nil {
		return err
	}

	mainTagName := firstname + lastname
	encMainTagName, err := s.Crypto.Encrypt(mainTagName)
	if err != nil {
		return err
	}

	return s.PersonsRepository.UpdatePersonWithTags(ctx, storedPerson, encFirstname, encLastname, encMainTagName, mainPersonTagId, idCategoryPerson, idUser, nicknames)
}

func (s *personsService) DeletePerson(ctx context.Context, idPerson uint, idUser uint64) error {
	return s.PersonsRepository.DeletePerson(ctx, idPerson, idUser)
}
