package application

import (
	"context"

	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/person"
)

// PersonsService is the use-case port of the Person aggregate. A person is
// represented in tagging by a single main tag ("Firstname Lastname");
// alternative names are plain tag synonyms of that main tag, managed through
// the tag endpoints like any other synonym.
type PersonsService interface {
	GetPersons(ctx context.Context, idUser uint64) ([]person.GetPersonsResponse, error)
	CreatePerson(ctx context.Context, p *person.Person, idUser uint64) error
	UpdatePerson(ctx context.Context, p *person.Person, idUser uint64) error
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
	persons, err := s.PersonsRepository.FindAllByUser(ctx, idUser)
	if err != nil {
		return nil, err
	}

	var responses = make([]person.GetPersonsResponse, 0, len(persons))
	for _, p := range persons {
		decFirstname, err := s.Crypto.Decrypt(p.Firstname, idUser)
		if err != nil {
			return nil, err
		}

		decLastname, err := s.Crypto.Decrypt(p.Lastname, idUser)
		if err != nil {
			return nil, err
		}

		responses = append(responses, person.GetPersonsResponse{
			Id:        p.Id,
			Firstname: decFirstname,
			Lastname:  decLastname,
		})
	}

	return responses, nil
}

func (s *personsService) CreatePerson(ctx context.Context, person *person.Person, idUser uint64) error {
	firstname := titleCase(person.Firstname)
	lastname := titleCase(person.Lastname)
	encFirstname, err := s.Crypto.Encrypt(firstname, idUser)
	if err != nil {
		return err
	}
	encLastname, err := s.Crypto.Encrypt(lastname, idUser)
	if err != nil {
		return err
	}

	mainTagName := firstname + lastname
	encMainTagName, err := s.Crypto.Encrypt(mainTagName, idUser)
	if err != nil {
		return err
	}

	idCategoryPerson, err := s.CategoriesRepository.FindIdByKind(ctx, idUser, category.KindPerson)
	if err != nil {
		return err
	}

	return s.PersonsRepository.CreatePersonWithMainTag(ctx, encFirstname, encLastname, encMainTagName, idCategoryPerson)
}

func (s *personsService) UpdatePerson(ctx context.Context, person *person.Person, idUser uint64) error {
	// Verify if the given id is a person of the user
	err := s.PersonsRepository.CheckPersonIdsWithTagsAndCategories(ctx, idUser, person.Id)
	if err != nil {
		return err
	}

	// The main tag mirrors the person's name, so it is renamed along.
	mainPersonTagId, err := s.CategoriesRepository.FindMainTagIdOfPerson(ctx, person.Id)
	if err != nil {
		return err
	}

	storedPerson, err := s.PersonsRepository.FindById(ctx, person.Id)
	if err != nil {
		return err
	}

	firstname := titleCase(person.Firstname)
	lastname := titleCase(person.Lastname)
	encFirstname, err := s.Crypto.Encrypt(firstname, idUser)
	if err != nil {
		return err
	}
	encLastname, err := s.Crypto.Encrypt(lastname, idUser)
	if err != nil {
		return err
	}

	mainTagName := firstname + lastname
	encMainTagName, err := s.Crypto.Encrypt(mainTagName, idUser)
	if err != nil {
		return err
	}

	return s.PersonsRepository.UpdatePersonWithMainTag(ctx, storedPerson, encFirstname, encLastname, encMainTagName, mainPersonTagId)
}

func (s *personsService) DeletePerson(ctx context.Context, idPerson uint, idUser uint64) error {
	return s.PersonsRepository.DeletePerson(ctx, idPerson, idUser)
}
