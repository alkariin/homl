package application

import (
	"context"
	"errors"
	"sort"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/e2ee"
)

// CategoriesService is the use-case port of the Category aggregate.
type CategoriesService interface {
	GetCategories(ctx context.Context, idUser uint64) ([]category.GetCategoryResponse, error)
	// CreateCategory returns the id of the created category, and whether it
	// was created by this call: false for a replay of an earlier create with
	// the same ClientId, which hands back the first category untouched.
	CreateCategory(ctx context.Context, c *category.Category) (uint, bool, error)
	UpdateCategory(ctx context.Context, c *category.Category) error
	DeleteCategory(ctx context.Context, idCategory uint, idUser uint64, moveTags bool, deleteEvents bool) error
	GetCategoryUsage(ctx context.Context, idCategory uint, idUser uint64) (*category.CategoryUsage, error)
}

type categoriesService struct {
	CategoriesRepository category.Repository
	Crypto               Encryptor
}

type CSConfig struct {
	CategoriesRepository category.Repository
	Crypto               Encryptor
}

func NewCategoriesService(c *CSConfig) CategoriesService {
	return &categoriesService{
		CategoriesRepository: c.CategoriesRepository,
		Crypto:               c.Crypto,
	}
}

func (c *categoriesService) GetCategories(ctx context.Context, idUser uint64) ([]category.GetCategoryResponse, error) {
	categories, tags, err := c.CategoriesRepository.GetAllCategoriesWithTags(ctx, idUser)
	if err != nil {
		return nil, err
	}
	groups, err := c.CategoriesRepository.GetAllTagGroups(ctx, idUser)
	if err != nil {
		return nil, err
	}

	isE2ee := e2ee.Enabled(ctx)

	keys := make([]int, 0)
	for k, _ := range categories {
		keys = append(keys, int(k))
	}
	sort.Ints(keys)
	var responses = make([]category.GetCategoryResponse, 0)
	for _, k := range keys {
		cat := categories[uint(k)]
		// E2EE names are opaque blobs returned verbatim; only the client can
		// decrypt them.
		decCategory := cat.Category
		if !isE2ee {
			decCategory, err = c.Crypto.Decrypt(cat.Category, idUser)
			if err != nil {
				return nil, err
			}
		}

		// A category without tags must serialize as [], not null: a missing
		// map key yields a nil slice, which encoding/json renders as null.
		catTags := tags[cat.Id]
		if catTags == nil {
			catTags = []category.TagDTO{}
		}
		catGroups := groups[cat.Id]
		if catGroups == nil {
			catGroups = []category.TagGroupDTO{}
		}

		response := category.GetCategoryResponse{
			Id:       cat.Id,
			Category: decCategory,
			Color:    cat.Color,
			IsLocked: cat.IsLocked,
			Kind:     cat.Kind,
			Tags:     catTags,
			Groups:   catGroups,
		}
		responses = append(responses, response)
	}
	return responses, nil
}

func (c *categoriesService) CreateCategory(ctx context.Context, newCategory *category.Category) (uint, bool, error) {
	// A client that lost the answer to a create sends it again with the
	// same ClientId: hand back the first category, touch nothing (the body
	// of a replay is not even validated).
	if newCategory.ClientId != nil {
		id, found, err := c.CategoriesRepository.FindIdByClientId(ctx, *newCategory.ClientId, newCategory.IdUser)
		if err != nil || found {
			return id, false, err
		}
	}

	encCategory, err := c.storedCategoryValue(ctx, newCategory, true)
	if err != nil {
		return 0, false, err
	}

	cat := &category.Category{
		Id:       newCategory.Id,
		Category: encCategory,
		Color:    newCategory.Color,
		IsLocked: false,
		IdUser:   newCategory.IdUser,
		ClientId: newCategory.ClientId,
	}

	id, err := c.CategoriesRepository.Create(ctx, cat)
	if errors.Is(err, category.ErrDuplicateClientId) {
		// Two replays raced and the other one inserted first: its row
		// stands.
		existing, found, findErr := c.CategoriesRepository.FindIdByClientId(ctx, *newCategory.ClientId, newCategory.IdUser)
		if findErr != nil {
			return 0, false, findErr
		}
		if !found {
			return 0, false, err
		}
		return existing, false, nil
	}
	if err != nil {
		return 0, false, err
	}
	return id, true, nil
}

func (c *categoriesService) UpdateCategory(ctx context.Context, newCategory *category.Category) error {
	// Scoped load: doubles as the ownership check for the update below.
	storedCategory, err := c.CategoriesRepository.FindByIdForUser(ctx, newCategory.Id, newCategory.IdUser)
	if err != nil {
		return err
	}

	// Locked categories (date, other) are read-only: neither their name nor
	// their color may change (Others must stay grey).
	if storedCategory.IsLocked {
		return apperror.NewStatusForbidden()
	}

	encCategory, err := c.storedCategoryValue(ctx, newCategory, false)
	if err != nil {
		return err
	}

	cat := &category.Category{
		Id:       newCategory.Id,
		Category: encCategory,
		Color:    newCategory.Color,
		IdUser:   newCategory.IdUser,
	}

	err = c.CategoriesRepository.Update(ctx, cat)
	if err != nil {
		return err
	}

	return nil
}

// storedCategoryValue returns the category name to persist: the validated
// client blob for E2EE users, the (optionally normalized) at-rest ciphertext
// otherwise. Historically only CreateCategory title-cases the name.
func (c *categoriesService) storedCategoryValue(ctx context.Context, newCategory *category.Category, normalize bool) (string, error) {
	if e2ee.Enabled(ctx) {
		if !e2ee.IsBlob(newCategory.Category) {
			return "", apperror.NewBadRequest("The given category is not a valid encrypted payload")
		}
		return newCategory.Category, nil
	}

	uCategory := newCategory.Category
	if normalize {
		uCategory = titleCase(uCategory)
	}
	return c.Crypto.Encrypt(uCategory, newCategory.IdUser)
}

// DeleteCategory removes a category: moveTags relocates its tags and tag
// groups to the Other category (refused with a conflict when a name is
// already taken there), otherwise deleteEvents decides whether the events
// whose only non-date tags lived here are deleted too or preserved
// date-only.
func (c *categoriesService) DeleteCategory(ctx context.Context, idCategory uint, idUser uint64, moveTags bool, deleteEvents bool) error {
	return c.CategoriesRepository.Delete(ctx, idCategory, idUser, moveTags, deleteEvents)
}

// GetCategoryUsage implements CategoriesService: tag/event counts used by the
// client to build its delete confirmation dialog.
func (c *categoriesService) GetCategoryUsage(ctx context.Context, idCategory uint, idUser uint64) (*category.CategoryUsage, error) {
	// Scoped load: doubles as the ownership check.
	if _, err := c.CategoriesRepository.FindByIdForUser(ctx, idCategory, idUser); err != nil {
		return nil, err
	}

	return c.CategoriesRepository.GetCategoryUsage(ctx, idCategory, idUser)
}
