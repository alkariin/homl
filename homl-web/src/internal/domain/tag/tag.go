// Package tag holds the Tag aggregate: entities, DTOs and the persistence port.
package tag

type Tag struct {
	Id         uint   `json:"id"`
	Tag        string `json:"tag"`
	IdCategory uint   `json:"idCategory"`
	IdPerson   uint   `json:"idPerson"`
}

type TagDTO struct {
	Id  uint   `json:"id"`
	Tag string `json:"tag"`
}

// Repository is the persistence port of the Tag aggregate.
type Repository interface {
	Create(tagNameEncrypt string, idCategory uint) error
	Update(tagNameEncrypt string, idCategory uint, idTag uint) error
	Delete(idTag uint, idUser uint64) error
	FindTagIdByTagAndIdCategory(encMonth string, idCategoryDate uint) (uint, error)
	FindMainTagIdOfPerson(idPerson uint) (uint, error)
}
