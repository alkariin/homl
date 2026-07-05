package application

import (
	"strings"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/masterdata"
)

// TagsService holds the tag use cases of the Category aggregate.
type TagsService interface {
	CreateTag(idUser uint64, t *category.Tag) error
	UpdateTag(idUser uint64, t *category.Tag) error
	DeleteTag(idTag uint, idUser uint64) error
}

type tagsService struct {
	CategoriesRepository category.Repository
	Crypto               Encryptor
}

type TSConfig struct {
	CategoriesRepository category.Repository
	Crypto               Encryptor
}

func NewTagsService(c *TSConfig) TagsService {
	return &tagsService{
		CategoriesRepository: c.CategoriesRepository,
		Crypto:               c.Crypto,
	}
}

// CreateTag implements TagsService.
func (t *tagsService) CreateTag(idUser uint64, tag *category.Tag) error {

	// Check that the idCategory is not Persons
	idCategoryDate, err := t.CategoriesRepository.FindLastIdByIdUser(idUser)
	if err != nil {
		return err
	}
	idCategoryPerson := idCategoryDate + 1

	if tag.IdCategory == idCategoryPerson {
		return apperror.NewBadRequest("The given idCategory is not valid")
	}

	// Check that the tag is not blacklisted
	blacklistTags := masterdata.BlacklistedTags()

	uTag := strings.Title(tag.Tag)

	for _, e := range blacklistTags {
		if e == uTag {
			return apperror.NewBadRequest("The given tag is not accepted")
		}
	}

	// Check that idCategory is the one of the user
	err = t.CategoriesRepository.CheckLastIdByIdAndIdUser(idUser, tag.IdCategory)
	if err != nil {
		return err
	}

	encTag, err := t.Crypto.Encrypt(uTag)
	if err != nil {
		return err
	}

	err = t.CategoriesRepository.CreateTag(encTag, tag.IdCategory)
	if err != nil {
		return err
	}

	return nil
}

// UpdateTag implements TagsService.
func (t *tagsService) UpdateTag(idUser uint64, tag *category.Tag) error {

	// Check that the idCategory is not Persons
	idCategoryDate, err := t.CategoriesRepository.FindLastIdByIdUser(idUser)
	if err != nil {
		return err
	}
	idCategoryPerson := idCategoryDate + 1

	if tag.IdCategory == idCategoryPerson {
		return apperror.NewBadRequest("The given idCategory is not valid")
	}

	// Check that the tag is not blacklisted
	blacklistTags := masterdata.BlacklistedTags()

	uTag := strings.Title(tag.Tag)

	for _, e := range blacklistTags {
		if e == uTag {
			return apperror.NewBadRequest("The given tag is not accepted")
		}
	}

	// Check that idCategory is the one of the user
	err = t.CategoriesRepository.CheckLastIdByIdAndIdUser(idUser, tag.IdCategory)
	if err != nil {
		return err
	}

	encTag, err := t.Crypto.Encrypt(uTag)
	if err != nil {
		return err
	}

	err = t.CategoriesRepository.UpdateTag(encTag, tag.IdCategory, tag.Id)
	if err != nil {
		return err
	}

	return err
}

// DeleteTag implements TagsService.
func (t *tagsService) DeleteTag(idTag uint, idUser uint64) error {
	return t.CategoriesRepository.DeleteTag(idTag, idUser)
}
