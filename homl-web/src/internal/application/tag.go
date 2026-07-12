package application

import (
	"context"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/masterdata"
)

// TagsService holds the tag use cases of the Category aggregate.
type TagsService interface {
	CreateTag(ctx context.Context, idUser uint64, t *category.Tag) (uint, error)
	UpdateTag(ctx context.Context, idUser uint64, t *category.Tag) error
	DeleteTag(ctx context.Context, idTag uint, idUser uint64, deleteEvents bool) error
	GetTagUsage(ctx context.Context, idTag uint, idUser uint64) (*category.TagUsage, error)
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
	// The target category must belong to the user and must not be the date
	// category: its month/year tags are managed by the backend only.
	targetCategory, err := t.CategoriesRepository.FindByIdForUser(ctx, tag.IdCategory, idUser)
	if err != nil {
		return "", apperror.NewBadRequest("The given idCategory is not valid")
	}

	if targetCategory.Kind == category.KindDate {
		return "", apperror.NewBadRequest("The given idCategory is not valid")
	}

	// Check that the tag is not blacklisted
	blacklistTags := masterdata.BlacklistedTags()

	uTag := titleCase(tag.Tag)

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

	encTag, err := t.Crypto.Encrypt(uTag, idUser)
	if err != nil {
		return 0, err
	}

	return t.CategoriesRepository.CreateTag(ctx, encTag, tag.IdCategory, tag.IdParentTag)
}

// UpdateTag implements TagsService.
func (t *tagsService) UpdateTag(ctx context.Context, idUser uint64, tag *category.Tag) error {
	// Check that the tag exists and belongs to the user
	storedTag, err := t.CategoriesRepository.FindTagForUser(ctx, tag.Id, idUser)
	if err != nil {
		return apperror.NewBadRequest("The given tag is not valid")
	}

	// A tag living in the date category is backend-managed (event month/year
	// tags): it cannot be renamed or moved out.
	if err := t.rejectDateCategoryTag(ctx, idUser, storedTag.IdCategory); err != nil {
		return err
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

	encTag, err := t.Crypto.Encrypt(uTag, idUser)
	if err != nil {
		return err
	}

	return t.CategoriesRepository.UpdateTag(ctx, encTag, tag.IdCategory, tag.Id, tag.IdParentTag)
}

// DeleteTag implements TagsService. deleteEvents only matters for main tags:
// it deletes the events whose only non-date tags belong to the deleted
// synonym group instead of preserving them date-only.
func (t *tagsService) DeleteTag(ctx context.Context, idTag uint, idUser uint64, deleteEvents bool) error {
	storedTag, err := t.CategoriesRepository.FindTagForUser(ctx, idTag, idUser)
	if err != nil {
		return apperror.NewBadRequest("The given tag is not valid")
	}

	// Date tags are backend-managed (event month/year tags): read-only.
	if err := t.rejectDateCategoryTag(ctx, idUser, storedTag.IdCategory); err != nil {
		return err
	}

	return t.CategoriesRepository.DeleteTag(ctx, idTag, idUser, deleteEvents)
}

// GetTagUsage implements TagsService: event counts for the tag's synonym
// group, used by the client to build its delete confirmation dialogs.
func (t *tagsService) GetTagUsage(ctx context.Context, idTag uint, idUser uint64) (*category.TagUsage, error) {
	// Scoped load: doubles as the ownership check.
	if _, err := t.CategoriesRepository.FindTagForUser(ctx, idTag, idUser); err != nil {
		return nil, apperror.NewBadRequest("The given tag is not valid")
	}

	return t.CategoriesRepository.GetTagUsage(ctx, idTag, idUser)
}

// rejectDateCategoryTag forbids the operation when the tag's current category
// is the user's date category, whose tags only the backend may touch.
func (t *tagsService) rejectDateCategoryTag(ctx context.Context, idUser uint64, idCategory uint) error {
	storedCategory, err := t.CategoriesRepository.FindByIdForUser(ctx, idCategory, idUser)
	if err != nil {
		return err
	}

	if storedCategory.Kind == category.KindDate {
		return apperror.NewStatusForbidden()
	}

	return nil
}
