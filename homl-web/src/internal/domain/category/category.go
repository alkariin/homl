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

// TagUsage reports how many events reference a tag's synonym group: Events
// counts every linked event, ExclusiveEvents the ones whose only non-date
// tags belong to the group (the events that would end up date-only if the
// group were deleted).
type TagUsage struct {
	Events          int `json:"events"`
	ExclusiveEvents int `json:"exclusiveEvents"`
}

// CategoryUsage reports how many tags a category holds and how many events
// reference them; ExclusiveEvents counts the events whose only non-date tags
// live in this category.
type CategoryUsage struct {
	Tags            int `json:"tags"`
	Events          int `json:"events"`
	ExclusiveEvents int `json:"exclusiveEvents"`
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
	// Delete removes a category. moveTags moves its tags (synonym links
	// intact) to the user's Other category; otherwise the tags are deleted
	// and deleteEvents decides whether the events left without any non-date
	// tag are deleted too or preserved with their date only.
	Delete(ctx context.Context, idCategory uint, idUser uint64, moveTags bool, deleteEvents bool) error
	// GetCategoryUsage counts the tags of a category and the events that
	// reference them.
	GetCategoryUsage(ctx context.Context, idCategory uint, idUser uint64) (*CategoryUsage, error)

	// CreateTag / UpdateTag store an encrypted tag name; tagIndex is the
	// client-side blind index of E2EE users (nil otherwise).
	CreateTag(ctx context.Context, tagNameEncrypt string, tagIndex *string, idCategory uint, idParentTag *uint) (uint, error)
	UpdateTag(ctx context.Context, tagNameEncrypt string, tagIndex *string, idCategory uint, idTag uint, idParentTag *uint) error
	// DeleteTag removes a tag. Deleting a synonym repoints its events to the
	// main tag; deleting a main tag deletes its whole synonym group and
	// deleteEvents decides whether the events left without any non-date tag
	// are deleted too or preserved with their date only.
	DeleteTag(ctx context.Context, idTag uint, idUser uint64, deleteEvents bool) error
	// GetTagUsage counts the events referencing a tag's synonym group.
	GetTagUsage(ctx context.Context, idTag uint, idUser uint64) (*TagUsage, error)
	// CheckTagsBelongToUser verifies that every id in tagsId is a tag living
	// in one of the user's categories; it errors when any id is unknown or
	// owned by another user.
	CheckTagsBelongToUser(ctx context.Context, tagsId []uint, idUser uint64) error
	FindTagIdByTagAndIdCategory(ctx context.Context, encTag string, idCategory uint) (uint, error)
	FindTagForUser(ctx context.Context, idTag uint, idUser uint64) (*Tag, error)
	HasSynonyms(ctx context.Context, idTag uint) (bool, error)
}
