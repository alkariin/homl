package application

import (
	"context"
	"strings"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/masterdata"
)

// TagsService holds the tag use cases of the Category aggregate.
type TagsService interface {
	CreateTag(ctx context.Context, idUser uint64, t *category.Tag) (uint, error)
	UpdateTag(ctx context.Context, idUser uint64, t *category.Tag) error
	DeleteTag(ctx context.Context, idTag uint, idUser uint64) error
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

// validateTag runs the checks shared by CreateTag and UpdateTag and returns
// the tag name ready to be encrypted.
func (t *tagsService) validateTag(ctx context.Context, idUser uint64, tag *category.Tag) (string, error) {
	// The target category must belong to the user and must not be the persons
	// category (person tags are only managed through the person endpoints).
	targetCategory, err := t.CategoriesRepository.FindByIdForUser(ctx, tag.IdCategory, idUser)
	if err != nil {
		return "", apperror.NewBadRequest("The given idCategory is not valid")
	}

	if targetCategory.Kind == category.KindPerson {
		return "", apperror.NewBadRequest("The given idCategory is not valid")
	}

	// Check that the tag is not blacklisted
	blacklistTags := masterdata.BlacklistedTags()

	uTag := strings.Title(tag.Tag)

	for _, e := range blacklistTags {
		if e == uTag {
			return "", apperror.NewBadRequest("The given tag is not accepted")
		}
	}

	if err := t.validateParent(ctx, idUser, tag); err != nil {
		return "", err
	}

	return uTag, nil
}

// validateParent enforces the synonym rules: one level of depth only, parent
// owned by the same user and living in the same category.
func (t *tagsService) validateParent(ctx context.Context, idUser uint64, tag *category.Tag) error {
	if tag.IdParentTag == nil {
		return nil
	}

	if *tag.IdParentTag == tag.Id {
		return apperror.NewBadRequest("A tag cannot be its own synonym")
	}

	parent, err := t.CategoriesRepository.FindTagForUser(ctx, *tag.IdParentTag, idUser)
	if err != nil {
		return apperror.NewBadRequest("The given idParentTag is not valid")
	}

	if parent.IdParentTag != nil {
		return apperror.NewBadRequest("A synonym cannot be a parent tag")
	}

	if parent.IdCategory != tag.IdCategory {
		return apperror.NewBadRequest("A synonym must be in the same category as its parent")
	}

	return nil
}

// CreateTag implements TagsService. It returns the id of the created tag.
func (t *tagsService) CreateTag(ctx context.Context, idUser uint64, tag *category.Tag) (uint, error) {
	uTag, err := t.validateTag(ctx, idUser, tag)
	if err != nil {
		return 0, err
	}

	encTag, err := t.Crypto.Encrypt(uTag)
	if err != nil {
		return 0, err
	}

	return t.CategoriesRepository.CreateTag(ctx, encTag, tag.IdCategory, tag.IdParentTag)
}

// UpdateTag implements TagsService.
func (t *tagsService) UpdateTag(ctx context.Context, idUser uint64, tag *category.Tag) error {
	// Check that the tag exists and belongs to the user, and that it is not a
	// person tag (nicknames are only managed through the person endpoints)
	storedTag, err := t.CategoriesRepository.FindTagForUser(ctx, tag.Id, idUser)
	if err != nil {
		return apperror.NewBadRequest("The given tag is not valid")
	}

	if storedTag.IdPerson != 0 {
		return apperror.NewBadRequest("The given tag is not valid")
	}

	// A tag that has synonyms cannot become a synonym itself (depth is one)
	if tag.IdParentTag != nil {
		hasSynonyms, err := t.CategoriesRepository.HasSynonyms(ctx, tag.Id)
		if err != nil {
			return err
		}
		if hasSynonyms {
			return apperror.NewBadRequest("A tag with synonyms cannot become a synonym")
		}
	}

	uTag, err := t.validateTag(ctx, idUser, tag)
	if err != nil {
		return err
	}

	encTag, err := t.Crypto.Encrypt(uTag)
	if err != nil {
		return err
	}

	return t.CategoriesRepository.UpdateTag(ctx, encTag, tag.IdCategory, tag.Id, tag.IdParentTag)
}

// DeleteTag implements TagsService.
func (t *tagsService) DeleteTag(ctx context.Context, idTag uint, idUser uint64) error {
	return t.CategoriesRepository.DeleteTag(ctx, idTag, idUser)
}
