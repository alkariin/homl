// Package user holds the User aggregate: entities, DTOs, auth value objects,
// per-user settings and the persistence port.
package user

type User struct {
	ID                   uint64  `json:"id"`
	Username             string  `json:"username"`
	Password             string  `json:"password"`
	IsFingerprintEnabled bool    `json:"isFingerprintEnabled"`
	IsPinEnabled         bool    `json:"isPinEnabled"`
	Pin                  *string `json:"pin"`
	PinTryCounter        *uint   `json:"pinTryCounter"`
	Pkey                 *string `json:"pkey"`
	Challenge            *string `json:"challenge"`
}

type UserResponse struct {
	IsFingerprintEnabled bool `json:"isFingerprintEnabled"`
	IsPinEnabled         bool `json:"isPinEnabled"`
}

type UserPassword struct {
	OldPassword string `json:"oldPassword"`
	NewPassword string `json:"newPassword"`
}

type RefreshInput struct {
	Refresh_token string  `json:"refresh_token"`
	Signature     *string `json:"signature,omitempty"`
	Pin           *string `json:"pin,omitempty"`
}

type AccessDetails struct {
	AccessUuid string
	UserId     uint64
}

// RefreshDetails is the metadata carried by a verified refresh token.
type RefreshDetails struct {
	RefreshUuid string
	UserId      uint64
}

type TokenDetails struct {
	AccessToken  string
	RefreshToken string
	AccessUuid   string
	RefreshUuid  string
	AtExpires    int64
	RtExpires    int64
}

// Repository is the persistence port of the User aggregate (MySQL + Redis auth
// store). Settings belong to the aggregate, so their persistence operations
// live here as well.
type Repository interface {
	// Registration creates the user and its default categories in one
	// transaction and fills in user.ID. Token creation is the application
	// layer's job.
	Registration(user *User, language *Language) error
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

	FindSettingsByIdUser(idUser uint64) (*Settings, error)
	UpdateSettings(s *Settings, idUser uint64) error
}
