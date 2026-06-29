package tag

import (
	"encoding/json"
	"strings"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/shared"
)

type tagsService struct {
	TagsRepository       domain.TagsRepository
	CategoriesRepository domain.CategoriesRepository
}

type TSConfig struct {
	TagsRepository       domain.TagsRepository
	CategoriesRepository domain.CategoriesRepository
}

func NewTagsService(c *TSConfig) domain.TagsService {
	return &tagsService{
		TagsRepository:       c.TagsRepository,
		CategoriesRepository: c.CategoriesRepository,
	}
}

// CreateTag implements domain.TagsService.
func (t *tagsService) CreateTag(idUser uint64, tag *domain.Tag) error {

	// Check that the idCategory is not Persons
	idCategoryDate, err := t.CategoriesRepository.FindLastIdByIdUser(idUser)
	if err != nil {
		return err
	}
	idCategoryPerson := idCategoryDate + 1

	if tag.IdCategory == idCategoryPerson {
		return shared.NewBadRequest("The given idCategory is not valid")
	}

	// Check that the tag is not blacklisted
	var constants map[string][]string
	constBytes, err := shared.GetConstants()
	if err != nil {
		return err
	}
	json.Unmarshal(constBytes, &constants)
	blacklistTags := constants["BLACKLIST_TAGS"]

	uTag := strings.Title(tag.Tag)

	for _, e := range blacklistTags {
		if e == uTag {
			return shared.NewBadRequest("The given tag is not accepted")
		}
	}

	// Check that idCategory is the one of the user
	err = t.CategoriesRepository.CheckLastIdByIdAndIdUser(idUser, tag.IdCategory)
	if err != nil {
		return err
	}

	encTag, err := shared.Encrypt(uTag)
	if err != nil {
		return err
	}

	err = t.TagsRepository.Create(encTag, tag.IdCategory)
	if err != nil {
		return err
	}

	return nil
}

// UpdateTag implements domain.TagsService.
func (t *tagsService) UpdateTag(idUser uint64, tag *domain.Tag) error {

	// Check that the idCategory is not Persons
	idCategoryDate, err := t.CategoriesRepository.FindLastIdByIdUser(idUser)
	if err != nil {
		return err
	}
	idCategoryPerson := idCategoryDate + 1

	if tag.IdCategory == idCategoryPerson {
		shared.NewBadRequest("The given idCategory is not valid")
	}

	// Check that the tag is not blacklisted
	var constants map[string][]string
	constBytes, err := shared.GetConstants()
	if err != nil {
		return err
	}
	json.Unmarshal(constBytes, &constants)
	blacklistTags := constants["BLACKLIST_TAGS"]

	uTag := strings.Title(tag.Tag)

	for _, e := range blacklistTags {
		if e == uTag {
			return shared.NewBadRequest("The given tag is not accepted")
		}
	}

	// Check that idCategory is the one of the user
	err = t.CategoriesRepository.CheckLastIdByIdAndIdUser(idUser, tag.IdCategory)
	if err != nil {
		return err
	}

	encTag, err := shared.Encrypt(uTag)
	if err != nil {
		return err
	}

	err = t.TagsRepository.Update(encTag, tag.IdCategory, tag.Id)
	if err != nil {
		return err
	}

	return err
}

// DeleteTag implements domain.TagsService.
func (t *tagsService) DeleteTag(idTag uint, idUser uint64) error {
	return t.TagsRepository.Delete(idTag, idUser)
}
