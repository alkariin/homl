// Package settings holds the Settings aggregate: entities, DTOs and the persistence port.
package settings

type Settings struct {
	Language      Language `json:"language"`
	DefaultScreen bool     `json:"defaultScreen"`
}

type SettingsResponse struct {
	Language      Language `json:"language"`
	DefaultScreen bool     `json:"defaultScreen"`
}

type Language string

const (
	de Language = "de"
	fr Language = "fr"
)

type Languages map[string]map[Language]string

// Repository is the persistence port of the Settings aggregate.
type Repository interface {
	FindByIdUser(idUser uint64) (*Settings, error)
	Update(s *Settings, idUser uint64) error
}
