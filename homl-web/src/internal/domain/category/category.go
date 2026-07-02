// Package category holds the Category aggregate: entities, DTOs and the persistence port.
package category

import "github.com/alkariin/homl/homl-web/internal/domain/tag"

type Category struct {
	Id       uint   `json:"id"`
	Category string `json:"category"`
	Color    string `json:"color"`
	IsLocked bool   `json:"isLocked"`
	IdUser   uint64 `json:"idUser"`
}

type GetCategoryResponse struct {
	Id       uint         `json:"id"`
	Category string       `json:"category"`
	Color    string       `json:"color"`
	IsLocked bool         `json:"isLocked"`
	Tags     []tag.TagDTO `json:"tags"`
}

// Repository is the persistence port of the Category aggregate.
type Repository interface {
	FindById(id uint) (*Category, error)
	FindLastIdByIdUser(idUser uint64) (uint, error)
	CheckLastIdByIdAndIdUser(idUser uint64, idCategory uint) error
	GetAllCategoriesWithTags(idUser uint64) (map[uint]Category, map[uint][]tag.TagDTO, error)
	Create(category *Category) error
	Update(category *Category) error
	Delete(idCategory uint, idUser uint64, moveTags bool) error
}
