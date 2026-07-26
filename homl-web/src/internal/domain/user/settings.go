package user

// Settings is a value object of the User aggregate: it has no identity of its
// own (one row per user, keyed by the user id).
type Settings struct {
	Language      Language `json:"language" db:"language"`
	DefaultScreen bool     `json:"defaultScreen" db:"defaultScreen"`
	// IsE2eeEnabled is read-only here: only the E2EE migration endpoint may
	// flip it (UpdateSettings ignores it). See docs/e2ee.md.
	IsE2eeEnabled bool `json:"isE2eeEnabled" db:"isE2eeEnabled"`
}

type SettingsResponse struct {
	Language      Language `json:"language"`
	DefaultScreen bool     `json:"defaultScreen"`
	IsE2eeEnabled bool     `json:"isE2eeEnabled"`
}

type Language string

type Languages map[string]map[Language]string
