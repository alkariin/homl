package application

import (
	"sort"
	"strings"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
)

// CategoriesService is the use-case port of the Category aggregate.
type CategoriesService interface {
	GetCategories(idUser uint64) ([]category.GetCategoryResponse, error)
	CreateCategory(c *category.Category) error
	UpdateCategory(c *category.Category) error
	DeleteCategory(idCategory uint, idUser uint64, moveTags bool) error
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

func (c *categoriesService) GetCategories(idUser uint64) ([]category.GetCategoryResponse, error) {
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

func (c *categoriesService) CreateCategory(newCategory *category.Category) error {
	uCategory := strings.Title(newCategory.Category)
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

	err = c.CategoriesRepository.Create(cat)
	if err != nil {
		return err
	}

	return nil
}

func (c *categoriesService) UpdateCategory(newCategory *category.Category) error {
	encCategory, err := c.Crypto.Encrypt(newCategory.Category)
	if err != nil {
		return err
	}

	storedCategory, err := c.CategoriesRepository.FindById(newCategory.Id)
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
