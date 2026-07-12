// Package person holds the Person aggregate: entities, DTOs and the persistence port.
package person

import "context"

type Person struct {
	Id         uint   `json:"id" db:"id"`
	Firstname  string `json:"firstname" db:"firstname"`
	Lastname   string `json:"lastname" db:"lastname"`
	IdCategory string `json:"idCategory" db:"idCategory"`
}

type GetPersonsResponse struct {
	Id        uint   `json:"id"`
	Firstname string `json:"firstname"`
	Lastname  string `json:"lastname"`
}

// Repository is the persistence port of the Person aggregate. A person is
// identified in tagging through a single main tag; alternative names are
// plain tag synonyms of that main tag, managed through the tag endpoints
// (they carry no person link).
type Repository interface {
	FindById(ctx context.Context, idPerson uint) (*Person, error)
	// FindAllByUser returns the user's persons sorted by id.
	FindAllByUser(ctx context.Context, idUser uint64) ([]Person, error)
	// CreatePersonWithMainTag stores the person and its main tag in one
	// transaction. The category is resolved (and user-scoped) by the caller.
	CreatePersonWithMainTag(ctx context.Context, encFirstname string, encLastname string, encMainTagName string, idCategoryPerson uint) error
	CheckPersonIdsWithTagsAndCategories(ctx context.Context, idUser uint64, idPerson uint) error
	// UpdatePersonWithMainTag renames the person and its main tag when the
	// name changed (the main tag mirrors "Firstname Lastname").
	UpdatePersonWithMainTag(ctx context.Context, storedPerson *Person, encFirstname string, encLastname string, encMainTagName string, mainPersonTagId uint) error
	DeletePerson(ctx context.Context, idPerson uint, idUser uint64) error
}
