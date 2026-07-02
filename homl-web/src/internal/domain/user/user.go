// Package user holds the User aggregate: entities, DTOs, auth value objects
// and the persistence port.
package user

import "github.com/alkariin/homl/homl-web/internal/domain/settings"

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

type TokenDetails struct {
	AccessToken  string
	RefreshToken string
	AccessUuid   string
	RefreshUuid  string
	AtExpires    int64
	RtExpires    int64
}

// Repository is the persistence port of the User aggregate (MySQL + Redis auth store).
type Repository interface {
	Registration(user *User, language *settings.Language) (map[string]string, error)
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
