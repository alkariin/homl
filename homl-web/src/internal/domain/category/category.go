// Package category holds the Category aggregate: the category root, its tag
// entities, DTOs and the persistence port.
package category

import "context"

type Category struct {
	Id       uint   `json:"id" db:"id"`
	Category string `json:"category" db:"category"`
	Color    string `json:"color" db:"color"`
	IsLocked bool   `json:"isLocked" db:"isLocked"`
	IdUser   uint64 `json:"idUser" db:"idUser"`
}

type GetCategoryResponse struct {
	Id       uint     `json:"id"`
	Category string   `json:"category"`
	Color    string   `json:"color"`
	IsLocked bool     `json:"isLocked"`
	Tags     []TagDTO `json:"tags"`
}

// Repository is the persistence port of the Category aggregate. Tags belong
// to the aggregate, so their persistence operations live here as well.
type Repository interface {
	FindById(ctx context.Context, id uint) (*Category, error)
	FindLastIdByIdUser(ctx context.Context, idUser uint64) (uint, error)
	CheckLastIdByIdAndIdUser(ctx context.Context, idUser uint64, idCategory uint) error
	GetAllCategoriesWithTags(ctx context.Context, idUser uint64) (map[uint]Category, map[uint][]TagDTO, error)
	Create(ctx context.Context, category *Category) error
	Update(ctx context.Context, category *Category) error
	Delete(ctx context.Context, idCategory uint, idUser uint64, moveTags bool) error

	CreateTag(ctx context.Context, tagNameEncrypt string, idCategory uint, idParentTag *uint) (uint, error)
	UpdateTag(ctx context.Context, tagNameEncrypt string, idCategory uint, idTag uint, idParentTag *uint) error
	DeleteTag(ctx context.Context, idTag uint, idUser uint64) error
	FindTagIdByTagAndIdCategory(ctx context.Context, encTag string, idCategory uint) (uint, error)
	FindMainTagIdOfPerson(ctx context.Context, idPerson uint) (uint, error)
	FindTagForUser(ctx context.Context, idTag uint, idUser uint64) (*Tag, error)
	HasSynonyms(ctx context.Context, idTag uint) (bool, error)
}
