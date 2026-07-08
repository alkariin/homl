package application

import (
	"context"
	"sort"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
)

// CategoriesService is the use-case port of the Category aggregate.
type CategoriesService interface {
	GetCategories(ctx context.Context, idUser uint64) ([]category.GetCategoryResponse, error)
	CreateCategory(ctx context.Context, c *category.Category) error
	UpdateCategory(ctx context.Context, c *category.Category) error
	DeleteCategory(ctx context.Context, idCategory uint, idUser uint64, moveTags bool) error
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
	// Returns all categories with all tags, but without the tags of the category persons
	categories, tags, err := c.CategoriesRepository.GetAllCategoriesWithTags(ctx, idUser)
	if err != nil {
		return nil, err
	}

	keys := make([]int, 0)
	for k, _ := range categories {
		keys = append(keys, int(k))
	}
	sort.Ints(keys)
	var responses = make([]category.GetCategoryResponse, 0)
	for _, k := range keys {
		cat := categories[uint(k)]
		decCategory, err := c.Crypto.Decrypt(cat.Category)
		if err != nil {
			return nil, err
		}

		response := category.GetCategoryResponse{
			Id:       cat.Id,
			Category: decCategory,
			Color:    cat.Color,
			IsLocked: cat.IsLocked,
			Tags:     tags[cat.Id],
		}
		responses = append(responses, response)
	}
	return responses, nil
}

func (c *categoriesService) CreateCategory(ctx context.Context, newCategory *category.Category) error {
	uCategory := titleCase(newCategory.Category)
	encCategory, err := c.Crypto.Encrypt(uCategory)
	if err != nil {
		return err
	}

	cat := &category.Category{
		Id:       newCategory.Id,
		Category: encCategory,
		Color:    newCategory.Color,
		IsLocked: false,
		IdUser:   newCategory.IdUser,
	}

	err = c.CategoriesRepository.Create(ctx, cat)
	if err != nil {
		return err
	}

	return nil
}

func (c *categoriesService) UpdateCategory(ctx context.Context, newCategory *category.Category) error {
	encCategory, err := c.Crypto.Encrypt(newCategory.Category)
	if err != nil {
		return err
	}

	// Scoped load: doubles as the ownership check for the update below.
	storedCategory, err := c.CategoriesRepository.FindByIdForUser(ctx, newCategory.Id, newCategory.IdUser)
	if err != nil {
		return err
	}

	// Do not update the name of the category
	if storedCategory.Category != encCategory && storedCategory.IsLocked {
		return apperror.NewStatusForbidden()
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

func (c *categoriesService) DeleteCategory(ctx context.Context, idCategory uint, idUser uint64, moveTags bool) error {
	return c.CategoriesRepository.Delete(ctx, idCategory, idUser, moveTags)
}
