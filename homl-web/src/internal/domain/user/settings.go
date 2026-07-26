package user

// Settings is a value object of the User aggregate: it has no identity of its
// own (one row per user, keyed by the user id).
type Settings struct {
	Language      Language `json:"language" db:"language"`
	DefaultScreen bool     `json:"defaultScreen" db:"defaultScreen"`
	// IsE2eeEnabled and E2eeKeyCheck are read-only here: only the E2EE
	// migration endpoint may change them (UpdateSettings ignores them). The
	// key check is exposed so a fresh device can verify a typed recovery
	// phrase before trusting it. See docs/e2ee.md.
	IsE2eeEnabled bool    `json:"isE2eeEnabled" db:"isE2eeEnabled"`
	E2eeKeyCheck  *string `json:"e2eeKeyCheck,omitempty" db:"e2eeKeyCheck"`
}

type SettingsResponse struct {
	Language      Language `json:"language"`
	DefaultScreen bool     `json:"defaultScreen"`
	IsE2eeEnabled bool     `json:"isE2eeEnabled"`
	E2eeKeyCheck  *string  `json:"e2eeKeyCheck,omitempty"`
}

type Language string

type Languages map[string]map[Language]string
