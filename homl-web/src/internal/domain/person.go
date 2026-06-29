package domain

type Person struct {
	Id         uint   `json:"id"`
	Firstname  string `json:"firstname"`
	Lastname   string `json:"lastname"`
	IdCategory string `json:"idCategory"`
}

type Nickname struct {
	Id       uint   `json:"id"`
	Nickname string `json:"nickname"`
}

type GetPersonsResponse struct {
	Person
	Nicknames []Nickname `json:"nicknames"`
}
