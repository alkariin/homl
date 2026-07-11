// Package masterdata exposes the static reference data shipped with the
// application (default categories, blacklisted tag names). The data is
// embedded at build time, so the binary no longer depends on a constants.json
// file sitting next to it at runtime.
package masterdata

import (
	_ "embed"
	"encoding/json"
)

//go:embed constants.json
var constantsJSON []byte

// Category is a default category seeded for every new user at registration.
type Category struct {
	Name  string
	Color string
	Kind  string
}

type constants struct {
	Categories    []Category `json:"CATEGORIES"`
	BlacklistTags []string   `json:"BLACKLIST_TAGS"`
}

var data constants

func init() {
	if err := json.Unmarshal(constantsJSON, &data); err != nil {
		panic("masterdata: invalid embedded constants.json: " + err.Error())
	}
}

// DefaultCategories returns the categories created for every new user,
// in seeding order (the first one is the "Dates" category).
func DefaultCategories() []Category {
	return data.Categories
}

// BlacklistedTags returns the tag names users are not allowed to create.
func BlacklistedTags() []string {
	return data.BlacklistTags
}
