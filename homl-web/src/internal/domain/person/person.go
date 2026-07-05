// Package person holds the Person aggregate: entities, DTOs and the persistence port.
package person

type Person struct {
	Id         uint   `json:"id"`
	Firstname  string `json:"firstname"`
	Lastname   string `json:"lastname"`
	IdCategory string `json:"idCategory"`
}

type Nickname struct {
	Id       uint   `json:"id"`
	Nickname string `json:"nickname"`
}

type GetPersonsResponse struct {
	Person
	Nicknames []Nickname `json:"nicknames"`
}

// Repository is the persistence port of the Person aggregate.
type Repository interface {
	FindById(idPerson uint) (*Person, error)
	FindPersonsWithTagsAndCategories(idUser uint64) (map[uint]Person, map[uint][]Nickname, error)
	CreatePersonWithTags(encFirstname string, encLastname string, encMainTagName string, idCategoryPerson uint, nicknames []string) error
	CheckPersonIdsWithTagsAndCategories(idUser uint64, idPerson uint) error
	UpdatePersonWithTags(
		storedPerson *Person,
		encFirstname string,
		encLastname string,
		encMainTagName string,
		mainPersonTagId uint,
		idCategoryPerson uint,
		idUser uint64,
		bodyNicknames []Nickname,
	) error
	DeletePerson(idPerson uint, idUser uint64) error
}
