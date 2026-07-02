package application

import (
	"strings"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/crypto"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/masterdata"
	"github.com/alkariin/homl/homl-web/internal/domain/tag"
)

// TagsService is the use-case port of the Tag aggregate.
type TagsService interface {
	CreateTag(idUser uint64, t *tag.Tag) error
	UpdateTag(idUser uint64, t *tag.Tag) error
	DeleteTag(idTag uint, idUser uint64) error
}

type tagsService struct {
	TagsRepository       tag.Repository
	CategoriesRepository category.Repository
}

type TSConfig struct {
	TagsRepository       tag.Repository
	CategoriesRepository category.Repository
}

func NewTagsService(c *TSConfig) TagsService {
	return &tagsService{
		TagsRepository:       c.TagsRepository,
		CategoriesRepository: c.CategoriesRepository,
	}
}

// CreateTag implements TagsService.
func (t *tagsService) CreateTag(idUser uint64, tag *tag.Tag) error {

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

	encTag, err := crypto.Encrypt(uTag)
	if err != nil {
		return err
	}

	err = t.TagsRepository.Create(encTag, tag.IdCategory)
	if err != nil {
		return err
	}

	return nil
}

// UpdateTag implements TagsService.
func (t *tagsService) UpdateTag(idUser uint64, tag *tag.Tag) error {

	// Check that the idCategory is not Persons
	idCategoryDate, err := t.CategoriesRepository.FindLastIdByIdUser(idUser)
	if err != nil {
		return err
	}
	idCategoryPerson := idCategoryDate + 1

	if tag.IdCategory == idCategoryPerson {
		apperror.NewBadRequest("The given idCategory is not valid")
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

	encTag, err := crypto.Encrypt(uTag)
	if err != nil {
		return err
	}

	err = t.TagsRepository.Update(encTag, tag.IdCategory, tag.Id)
	if err != nil {
		return err
	}

	return err
}

// DeleteTag implements TagsService.
func (t *tagsService) DeleteTag(idTag uint, idUser uint64) error {
	return t.TagsRepository.Delete(idTag, idUser)
}
