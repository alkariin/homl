package category

// Tag is an entity of the Category aggregate: a tag never exists without its
// owning category, and its lifecycle (move on delete, blacklist rules) is
// enforced through the category root.
type Tag struct {
	Id         uint   `json:"id"`
	Tag        string `json:"tag"`
	IdCategory uint   `json:"idCategory"`
	IdPerson   uint   `json:"idPerson"`
}

type TagDTO struct {
	Id  uint   `json:"id"`
	Tag string `json:"tag"`
}
