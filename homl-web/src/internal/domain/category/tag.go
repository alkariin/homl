package category

// Tag is an entity of the Category aggregate: a tag never exists without its
// owning category, and its lifecycle (move on delete, blacklist rules) is
// enforced through the category root.
type Tag struct {
	Id         uint   `json:"id" db:"id"`
	Tag        string `json:"tag" db:"tag"`
	IdCategory uint   `json:"idCategory" db:"idCategory"`
	// IdParentTag links a synonym to its main tag (nil = main tag).
	// Depth is limited to one level: a synonym can never be a parent.
	IdParentTag *uint `json:"idParentTag" db:"idParentTag"`
}

type TagDTO struct {
	Id          uint   `json:"id"`
	Tag         string `json:"tag"`
	IdParentTag *uint  `json:"idParentTag"`
}
