package category

// TagGroup is an entity of the Category aggregate: a named set of main tags
// of its category ("Family" = the tags of the family members). It is a
// shortcut, never linked to an event: the client expands it into its members
// when the user picks it. See docs/tag-groups.md.
type TagGroup struct {
	Id         uint   `json:"id" db:"id"`
	Name       string `json:"name" db:"name"`
	IdCategory uint   `json:"idCategory" db:"idCategory"`
	// Members are the ids of the grouped tags: main tags of the group's
	// category, at least one on every write.
	Members []uint `json:"members"`
	// NameIndex is the client-side blind index of the normalized name,
	// required from E2EE users and NULL otherwise (the same HMAC as
	// Tag.TagIndex). See docs/e2ee.md.
	NameIndex *string `json:"nameIndex,omitempty" db:"nameIndex"`
}

type TagGroupDTO struct {
	Id      uint   `json:"id"`
	Name    string `json:"name"`
	Members []uint `json:"members"`
}
