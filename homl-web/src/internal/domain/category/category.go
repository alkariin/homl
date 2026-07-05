// Package category holds the Category aggregate: the category root, its tag
// entities, DTOs and the persistence port.
package category

type Category struct {
	Id       uint   `json:"id"`
	Category string `json:"category"`
	Color    string `json:"color"`
	IsLocked bool   `json:"isLocked"`
	IdUser   uint64 `json:"idUser"`
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
	FindById(id uint) (*Category, error)
	FindLastIdByIdUser(idUser uint64) (uint, error)
	CheckLastIdByIdAndIdUser(idUser uint64, idCategory uint) error
	GetAllCategoriesWithTags(idUser uint64) (map[uint]Category, map[uint][]TagDTO, error)
	Create(category *Category) error
	Update(category *Category) error
	Delete(idCategory uint, idUser uint64, moveTags bool) error

	CreateTag(tagNameEncrypt string, idCategory uint) error
	UpdateTag(tagNameEncrypt string, idCategory uint, idTag uint) error
	DeleteTag(idTag uint, idUser uint64) error
	FindTagIdByTagAndIdCategory(encTag string, idCategory uint) (uint, error)
	FindMainTagIdOfPerson(idPerson uint) (uint, error)
}
