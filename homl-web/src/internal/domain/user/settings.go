package user

// Settings is a value object of the User aggregate: it has no identity of its
// own (one row per user, keyed by the user id).
type Settings struct {
	Language      Language `json:"language" db:"language"`
	DefaultScreen bool     `json:"defaultScreen" db:"defaultScreen"`
}

type SettingsResponse struct {
	Language      Language `json:"language"`
	DefaultScreen bool     `json:"defaultScreen"`
}

type Language string

type Languages map[string]map[Language]string
