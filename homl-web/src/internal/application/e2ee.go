package application

import (
	"context"
	"strings"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/e2ee"
)

// Migration directions accepted by E2EEService.Migrate.
const (
	E2EEDirectionEnable  = "enable"
	E2EEDirectionDisable = "disable"
)

// E2EEService holds the use cases of the opt-in end-to-end encryption
// feature (see docs/e2ee.md): the atomic enable/disable migration and the
// lost-key purge.
type E2EEService interface {
	Migrate(ctx context.Context, idUser uint64, direction string, keyCheck string, data *e2ee.MigrationData) error
	Purge(ctx context.Context, idUser uint64) error
}

type e2eeService struct {
	E2EERepository e2ee.Repository
}

type E2EEConfig struct {
	E2EERepository e2ee.Repository
}

func NewE2EEService(c *E2EEConfig) E2EEService {
	return &e2eeService{
		E2EERepository: c.E2EERepository,
	}
}

// Migrate validates and applies the whole-dataset swap. On enable every value
// must be a well-formed client blob and every tag must carry its blind index;
// on disable the values are plaintext and tag/category names are re-normalized
// before the repository re-encrypts them with the at-rest scheme.
func (s *e2eeService) Migrate(ctx context.Context, idUser uint64, direction string, keyCheck string, data *e2ee.MigrationData) error {
	switch direction {
	case E2EEDirectionEnable:
		if !e2ee.IsKeyCheck(keyCheck) {
			return apperror.NewBadRequest("The given keyCheck is not valid")
		}
		if err := validateE2EEData(data); err != nil {
			return err
		}
		return s.E2EERepository.Migrate(ctx, idUser, true, &keyCheck, data)

	case E2EEDirectionDisable:
		// Plaintext values coming back from the client may have been edited
		// under E2EE with arbitrary casing: re-apply the normalization the
		// at-rest deterministic scheme relies on for lookups.
		for i := range data.Categories {
			if strings.TrimSpace(data.Categories[i].Category) == "" {
				return apperror.NewBadRequest("A category name cannot be empty")
			}
			data.Categories[i].Category = titleCase(data.Categories[i].Category)
		}
		for i := range data.Tags {
			if strings.TrimSpace(data.Tags[i].Tag) == "" {
				return apperror.NewBadRequest("A tag name cannot be empty")
			}
			data.Tags[i].Tag = titleCase(data.Tags[i].Tag)
			data.Tags[i].TagIndex = nil
		}
		return s.E2EERepository.Migrate(ctx, idUser, false, nil, data)

	default:
		return apperror.NewBadRequest("The given direction is not valid")
	}
}

// validateE2EEData checks the shape of every client-encrypted value of an
// enable migration.
func validateE2EEData(data *e2ee.MigrationData) error {
	for _, c := range data.Categories {
		if !e2ee.IsBlob(c.Category) {
			return apperror.NewBadRequest("A category value is not a valid encrypted payload")
		}
	}
	for _, t := range data.Tags {
		if !e2ee.IsBlob(t.Tag) {
			return apperror.NewBadRequest("A tag value is not a valid encrypted payload")
		}
		if t.TagIndex == nil || !e2ee.IsIndex(*t.TagIndex) {
			return apperror.NewBadRequest("A tag is missing a valid tagIndex")
		}
	}
	for _, ev := range data.Events {
		// An omitted description stays empty in both modes.
		if ev.Description != "" && !e2ee.IsBlob(ev.Description) {
			return apperror.NewBadRequest("An event description is not a valid encrypted payload")
		}
	}
	return nil
}

func (s *e2eeService) Purge(ctx context.Context, idUser uint64) error {
	return s.E2EERepository.Purge(ctx, idUser)
}
