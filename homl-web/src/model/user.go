package model

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
