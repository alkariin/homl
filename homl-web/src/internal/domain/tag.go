package domain

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
