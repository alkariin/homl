package model

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
