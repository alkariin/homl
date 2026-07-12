// Package category holds the Category aggregate: the category root, its tag
// entities, DTOs and the persistence port.
package category

import "context"

// Kind identifies the role of a category. Every user gets a date, person and
// other category at registration; date and other are locked, person is a
// plain unlocked suggestion (see docs/default-categories.md). Everything the
// user creates afterwards is custom.
type Kind string

const (
	KindDate   Kind = "date"
	KindPerson Kind = "person"
	KindOther  Kind = "other"
	KindCustom Kind = "custom"
)

type Category struct {
	Id       uint   `json:"id" db:"id"`
	Category string `json:"category" db:"category"`
	Color    string `json:"color" db:"color"`
	IsLocked bool   `json:"isLocked" db:"isLocked"`
	Kind     Kind   `json:"kind" db:"kind"`
	IdUser   uint64 `json:"idUser" db:"idUser"`
}

type GetCategoryResponse struct {
	Id       uint     `json:"id"`
	Category string   `json:"category"`
	Color    string   `json:"color"`
	IsLocked bool     `json:"isLocked"`
	Kind     Kind     `json:"kind"`
	Tags     []TagDTO `json:"tags"`
}

// Repository is the persistence port of the Category aggregate. Tags belong
// to the aggregate, so their persistence operations live here as well.
// Every method is scoped to the owning user: no operation may read or write
// another user's categories or tags.
type Repository interface {
	// FindByIdForUser loads a category owned by the given user (sql.ErrNoRows
	// when it does not exist or belongs to someone else).
	FindByIdForUser(ctx context.Context, id uint, idUser uint64) (*Category, error)
	// FindIdByKind returns the id of the user's default category of the given
	// kind (date, person or other).
	FindIdByKind(ctx context.Context, idUser uint64, kind Kind) (uint, error)
	GetAllCategoriesWithTags(ctx context.Context, idUser uint64) (map[uint]Category, map[uint][]TagDTO, error)
	Create(ctx context.Context, category *Category) error
	Update(ctx context.Context, category *Category) error
	Delete(ctx context.Context, idCategory uint, idUser uint64, moveTags bool) error

	CreateTag(ctx context.Context, tagNameEncrypt string, idCategory uint, idParentTag *uint) (uint, error)
	UpdateTag(ctx context.Context, tagNameEncrypt string, idCategory uint, idTag uint, idParentTag *uint) error
	DeleteTag(ctx context.Context, idTag uint, idUser uint64) error
	// CheckTagsBelongToUser verifies that every id in tagsId is a tag living
	// in one of the user's categories; it errors when any id is unknown or
	// owned by another user.
	CheckTagsBelongToUser(ctx context.Context, tagsId []uint, idUser uint64) error
	FindTagIdByTagAndIdCategory(ctx context.Context, encTag string, idCategory uint) (uint, error)
	FindTagForUser(ctx context.Context, idTag uint, idUser uint64) (*Tag, error)
	HasSynonyms(ctx context.Context, idTag uint) (bool, error)
}
