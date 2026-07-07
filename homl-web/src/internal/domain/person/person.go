// Package person holds the Person aggregate: entities, DTOs and the persistence port.
package person

import "context"

type Person struct {
	Id         uint   `json:"id" db:"id"`
	Firstname  string `json:"firstname" db:"firstname"`
	Lastname   string `json:"lastname" db:"lastname"`
	IdCategory string `json:"idCategory" db:"idCategory"`
}

type Nickname struct {
	Id       uint   `json:"id" db:"id"`
	Nickname string `json:"nickname" db:"nickname"`
}

type GetPersonsResponse struct {
	Person
	Nicknames []Nickname `json:"nicknames"`
}

// Repository is the persistence port of the Person aggregate.
type Repository interface {
	FindById(ctx context.Context, idPerson uint) (*Person, error)
	FindPersonsWithTagsAndCategories(ctx context.Context, idUser uint64) (map[uint]Person, map[uint][]Nickname, error)
	CreatePersonWithTags(ctx context.Context, encFirstname string, encLastname string, encMainTagName string, idCategoryPerson uint, nicknames []string) error
	CheckPersonIdsWithTagsAndCategories(ctx context.Context, idUser uint64, idPerson uint) error
	UpdatePersonWithTags(
		ctx context.Context,
		storedPerson *Person,
		encFirstname string,
		encLastname string,
		encMainTagName string,
		mainPersonTagId uint,
		idCategoryPerson uint,
		idUser uint64,
		bodyNicknames []Nickname,
	) error
	DeletePerson(ctx context.Context, idPerson uint, idUser uint64) error
}
