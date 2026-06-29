package domain

type Category struct {
	Id       uint   `json:"id"`
	Category string `json:"category"`
	Color    string `json:"color"`
	IsLocked bool   `json:"isLocked"`
	IdUser   uint64 `json:"idUser"`
}

type GetCategoryResponse struct {
	Id       uint     `json:"id"`
	Category string   `json:"category"`
	Color    string   `json:"color"`
	IsLocked bool     `json:"isLocked"`
	Tags     []TagDTO `json:"tags"`
}

type CategoryConstant []struct {
	Name  string
	Color string
}
