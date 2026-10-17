package application

import (
	"context"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/e2ee"
)

// TagGroupsService holds the tag group use cases of the Category aggregate
// (see docs/tag-groups.md).
type TagGroupsService interface {
	CreateTagGroup(ctx context.Context, idUser uint64, g *category.TagGroup) (uint, error)
	UpdateTagGroup(ctx context.Context, idUser uint64, g *category.TagGroup) error
	DeleteTagGroup(ctx context.Context, idGroup uint, idUser uint64) error
}

type tagGroupsService struct {
	CategoriesRepository category.Repository
	Crypto               Encryptor
}

type TGSConfig struct {
	CategoriesRepository category.Repository
	Crypto               Encryptor
}

func NewTagGroupsService(c *TGSConfig) TagGroupsService {
	return &tagGroupsService{
		CategoriesRepository: c.CategoriesRepository,
		Crypto:               c.Crypto,
	}
}

// validateTagGroup runs the checks shared by CreateTagGroup and
// UpdateTagGroup against the group's category and returns the name to store
// (at-rest ciphertext, or the client blob as-is for E2EE users) and the
// deduplicated members.
func (s *tagGroupsService) validateTagGroup(ctx context.Context, idUser uint64, idCategory uint, g *category.TagGroup) (string, []uint, error) {
	// The date tags are derived from the event periods, never picked by
	// the user: there is nothing to group there, E2EE or not.
	targetCategory, err := s.CategoriesRepository.FindByIdForUser(ctx, idCategory, idUser)
	if err != nil || targetCategory.Kind == category.KindDate {
		return "", nil, apperror.NewBadRequest("The given idCategory is not valid")
	}

	members := make([]uint, 0, len(g.Members))
	seen := make(map[uint]struct{}, len(g.Members))
	for _, id := range g.Members {
		if _, dup := seen[id]; !dup {
			seen[id] = struct{}{}
			members = append(members, id)
		}
	}
	if len(members) == 0 {
		return "", nil, apperror.NewBadRequest("A group needs at least one member")
	}
	if err := s.CategoriesRepository.CheckMainTagsInCategory(ctx, members, idCategory, idUser); err != nil {
		return "", nil, err
	}

	if e2ee.Enabled(ctx) {
		// Normalization and the reserved names are enforced client-side
		// before encryption; the server can only check the shape.
		if !e2ee.IsBlob(g.Name) {
			return "", nil, apperror.NewBadRequest("The given name is not a valid encrypted payload")
		}
		if g.NameIndex == nil || !e2ee.IsIndex(*g.NameIndex) {
			return "", nil, apperror.NewBadRequest("The given nameIndex is not valid")
		}
		return g.Name, members, nil
	}

	// A group name follows the tag name rules: the user types both in the
	// same field, and a month or a year has to stay a date tag there.
	uName := titleCase(g.Name)
	if isReservedTagName(uName) {
		return "", nil, apperror.NewBadRequest("The given name is not accepted")
	}

	encName, err := s.Crypto.Encrypt(uName, idUser)
	if err != nil {
		return "", nil, err
	}
	return encName, members, nil
}

// nameIndexToStore returns the blind index to persist: the client's for E2EE
// users, none otherwise (a stray nameIndex from a non-E2EE client is
// dropped).
func nameIndexToStore(ctx context.Context, g *category.TagGroup) *string {
	if e2ee.Enabled(ctx) {
		return g.NameIndex
	}
	return nil
}

// CreateTagGroup implements TagGroupsService. It returns the id of the
// created group.
func (s *tagGroupsService) CreateTagGroup(ctx context.Context, idUser uint64, g *category.TagGroup) (uint, error) {
	name, members, err := s.validateTagGroup(ctx, idUser, g.IdCategory, g)
	if err != nil {
		return 0, err
	}

	return s.CategoriesRepository.CreateTagGroup(ctx, name, nameIndexToStore(ctx, g), g.IdCategory, members)
}

// UpdateTagGroup implements TagGroupsService: a full-state write of the name
// and the members. A group never changes category (its members could not
// follow), so the stored one is validated against and idCategory ignored.
func (s *tagGroupsService) UpdateTagGroup(ctx context.Context, idUser uint64, g *category.TagGroup) error {
	stored, err := s.CategoriesRepository.FindTagGroupForUser(ctx, g.Id, idUser)
	if err != nil {
		return apperror.NewBadRequest("The given group is not valid")
	}

	name, members, err := s.validateTagGroup(ctx, idUser, stored.IdCategory, g)
	if err != nil {
		return err
	}

	return s.CategoriesRepository.UpdateTagGroup(ctx, name, nameIndexToStore(ctx, g), g.Id, members)
}

// DeleteTagGroup implements TagGroupsService. Only the shortcut goes: the
// tags and their events are untouched.
func (s *tagGroupsService) DeleteTagGroup(ctx context.Context, idGroup uint, idUser uint64) error {
	return s.CategoriesRepository.DeleteTagGroup(ctx, idGroup, idUser)
}
