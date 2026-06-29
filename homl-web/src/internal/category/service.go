package category

import (
	"sort"
	"strings"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/shared"
)

type categoriesService struct {
	CategoriesRepository domain.CategoriesRepository
}

type CSConfig struct {
	CategoriesRepository domain.CategoriesRepository
}

func NewCategoriesService(c *CSConfig) domain.CategoriesService {
	return &categoriesService{
		CategoriesRepository: c.CategoriesRepository,
	}
}

func (c *categoriesService) GetCategories(idUser uint64) ([]domain.GetCategoryResponse, error) {
	// Returns all categories with all tags, but without the tags of the category persons
	categories, tags, err := c.CategoriesRepository.GetAllCategoriesWithTags(idUser)
	if err != nil {
		return nil, err
	}

	keys := make([]int, 0)
	for k, _ := range categories {
		keys = append(keys, int(k))
	}
	sort.Ints(keys)
	var responses = make([]domain.GetCategoryResponse, 0)
	for _, k := range keys {
		category := categories[uint(k)]
		decCategory, err := shared.Decrypt(category.Category)
		if err != nil {
			return nil, err
		}

		response := domain.GetCategoryResponse{
			Id:       category.Id,
			Category: decCategory,
			Color:    category.Color,
			IsLocked: category.IsLocked,
			Tags:     tags[category.Id],
		}
		responses = append(responses, response)
	}
	return responses, nil
}

func (c *categoriesService) CreateCategory(category *domain.Category) error {
	uCategory := strings.Title(category.Category)
	encCategory, err := shared.Encrypt(uCategory)
	if err != nil {
		return err
	}

	cat := &domain.Category{
		Id:       category.Id,
		Category: encCategory,
		Color:    category.Color,
		IsLocked: false,
		IdUser:   category.IdUser,
	}

	err = c.CategoriesRepository.Create(cat)
	if err != nil {
		return err
	}

	return nil
}

func (c *categoriesService) UpdateCategory(category *domain.Category) error {
	encCategory, err := shared.Encrypt(category.Category)
	if err != nil {
		return err
	}

	storedCategory, err := c.CategoriesRepository.FindById(category.Id)
	if err != nil {
		return err
	}

	// Do not update the name of the category
	if storedCategory.Category != encCategory && storedCategory.IsLocked {
		return shared.NewStatusForbidden()
	}

	cat := &domain.Category{
		Id:       category.Id,
		Category: encCategory,
		Color:    category.Color,
	}

	err = c.CategoriesRepository.Update(cat)
	if err != nil {
		return err
	}

	return nil
}

func (c *categoriesService) DeleteCategory(idCategory uint, idUser uint64, moveTags bool) error {
	return c.CategoriesRepository.Delete(idCategory, idUser, moveTags)
}
