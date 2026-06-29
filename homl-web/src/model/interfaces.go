package model

import "net/http"

type CategoriesRepository interface {
	FindById(id uint) (*Category, error)
	FindLastIdByIdUser(idUser uint64) (uint, error)
	CheckLastIdByIdAndIdUser(idUser uint64, idCategory uint) error
	GetAllCategoriesWithTags(idUser uint64) (map[uint]Category, map[uint][]TagDTO, error)
	Create(category *Category) error
	Update(category *Category) error
	Delete(idCategory uint, idUser uint64, moveTags bool) error
}

type CategoriesService interface {
	GetCategories(idUser uint64) ([]GetCategoryResponse, error)
	CreateCategory(category *Category) error
	UpdateCategory(category *Category) error
	DeleteCategory(idCategory uint, idUser uint64, moveTags bool) error
}

type EventsRepository interface {
	FindEventsWithTags(encTags []string, idUser uint64) (map[uint]Event, map[uint][]Tag, error)
	CreateEventWithTags(tags []Tag, tagsId []uint, event *Event, idUser uint64) error
	UpdateEventWithTags(tags []Tag, tagsId []uint, event *Event, idUser uint64) error
	Delete(id uint) error
}

type EventsService interface {
	GetEvents(idUser uint64, tags []string) ([]GetEventsResponse, error)
	CreateEvent(idUser uint64, event *Event, tagsId []uint) error
	UpdateEvent(idUser uint64, event *Event, tagsId []uint) error
	DeleteEvent(idEvent uint) error
}

type PersonsRepository interface {
	FindById(idPerson uint) (*Person, error)
	FindPersonsWithTagsAndCategories(idUser uint64) (map[uint]Person, map[uint][]Nickname, error)
	CreatePersonWithTags(encFirstname string, encLastname string, encMainTagName string, idCategoryPerson uint, nicknames []string) error
	CheckPersonIdsWithTagsAndCategories(idUser uint64, idPerson uint) error
	UpdatePersonWithTags(
		storedPerson *Person,
		encFirstname string,
		encLastname string,
		encMainTagName string,
		mainPersonTagId uint,
		idCategoryPerson uint,
		idUser uint64,
		bodyNicknames []Nickname,
	) error
	DeletePerson(idPerson uint, idUser uint64) error
}

type PersonsService interface {
	GetPersons(idUser uint64) ([]GetPersonsResponse, error)
	CreatePerson(person *Person, nicknames []string, idUser uint64) error
	UpdatePerson(person *Person, nicknames []Nickname, idUser uint64) error
	DeletePerson(idPerson uint, idUser uint64) error
}

type SettingsRepository interface {
	FindByIdUser(idUser uint64) (*Settings, error)
	Update(s *Settings, idUser uint64) error
}

type SettingsService interface {
	GetSettings(idUser uint64) (*SettingsResponse, error)
	UpdateSettings(idUser uint64, settings *Settings) (*SettingsResponse, error)
}

type TagsRepository interface {
	Create(tagNameEncrypt string, idCategory uint) error
	Update(tagNameEncrypt string, idCategory uint, idTag uint) error
	Delete(idTag uint, idUser uint64) error
	FindTagIdByTagAndIdCategory(encMonth string, idCategoryDate uint) (uint, error)
	FindMainTagIdOfPerson(idPerson uint) (uint, error)
}

type TagsService interface {
	CreateTag(idUser uint64, tag *Tag) error
	UpdateTag(idUser uint64, tag *Tag) error
	DeleteTag(idTag uint, idUser uint64) error
}

type UsersRepository interface {
	Registration(user *User, language *Language) (map[string]string, error)
	FindById(idUser uint64) (*User, error)
	FindByUsername(username string) (*User, error)
	FindIdByUsername(username string) (uint64, error)
	FindPkeyAndChallengeById(idUser uint64) (*User, error)
	UpdatePassword(idUser uint64, hashedPassword string) error
	FindPasswordById(idUser uint64) (*string, error)
	UpdateChallenge(idUser uint64, challenge *string) error
	ResetPinCounter(idUser uint64) error
	CheckPin(idUser uint64, pin string) error
	DeleteAuth(givenUuid string) (int64, error)
	CreateAuth(userid uint64, td *TokenDetails) error
	FetchAuth(authD *AccessDetails) (uint64, error)
	UpdatePinAndFingerprint(user *User, removePkey bool, removePin bool) error
}

type UsersService interface {
	Registration(user *User, language *Language) (map[string]string, error)
	Login(user *User) (map[string]string, error)
	Logout(accessDetails *AccessDetails) error
	Refresh(refreshInput *RefreshInput) (map[string]string, error)
	ResetPassword(user *User) error
	ConfirmResetPassword(user *User) (map[string]string, error)
	UpdatePassword(oldPassword string, newPassword string, idUser uint64) (map[string]string, error)
	Challenge(refreshToken string) (*string, error)
	GetUserIdFromToken(request *http.Request) (uint64, error)
	SecureAuth(user *User) (*UserResponse, error)
}
