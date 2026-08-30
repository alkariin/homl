// Package user holds the User aggregate: entities, DTOs, auth value objects,
// per-user settings and the persistence port.
package user

import (
	"context"
	"errors"
	"time"
)

// ErrResetCooldown is returned by StoreResetCode when a reset code was
// requested again before the per-user cooldown elapsed.
var ErrResetCooldown = errors.New("reset code requested too recently")

// PasswordBcryptCost is the bcrypt work factor for account passwords. 12 is a
// sane floor for 2026; the pin uses its own (lower) cost since it is a
// low-entropy secret protected by a hard lockout.
const PasswordBcryptCost = 12

// MaxPinTries is the hard lockout threshold for wrong pin attempts. Once
// reached, even a correct pin is refused until a password login resets it.
const MaxPinTries = 3

type User struct {
	ID                   uint64  `json:"id" db:"id"`
	Username             string  `json:"username" db:"username"`
	Password             string  `json:"password" db:"password"`
	IsFingerprintEnabled bool    `json:"isFingerprintEnabled" db:"isFingerprintEnabled"`
	IsPinEnabled         bool    `json:"isPinEnabled" db:"isPinEnabled"`
	Pin                  *string `json:"pin" db:"pin"`
	PinTryCounter        *uint   `json:"pinTryCounter" db:"pinTryCounter"`
	Pkey                 *string `json:"pkey" db:"pkey"`
	Challenge            *string `json:"challenge" db:"challenge"`
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
	Registration(ctx context.Context, user *User, language *Language) error
	FindById(ctx context.Context, idUser uint64) (*User, error)
	FindByUsername(ctx context.Context, username string) (*User, error)
	FindIdByUsername(ctx context.Context, username string) (uint64, error)
	FindPkeyAndChallengeById(ctx context.Context, idUser uint64) (*User, error)
	UpdatePassword(ctx context.Context, idUser uint64, hashedPassword string) error
	FindPasswordById(ctx context.Context, idUser uint64) (*string, error)
	UpdateChallenge(ctx context.Context, idUser uint64, challenge *string) error
	ResetPinCounter(ctx context.Context, idUser uint64) error
	CheckPin(ctx context.Context, idUser uint64, pin string) error
	CreateAuth(ctx context.Context, userid uint64, td *TokenDetails) error
	FetchAuth(ctx context.Context, authD *AccessDetails) (uint64, error)
	// RevokeSessionByAccess / RevokeSessionByRefresh delete a whole session
	// pair (access + refresh) given either of its uuids, returning how many
	// keys were removed (0 = the session was already gone).
	RevokeSessionByAccess(ctx context.Context, accessUuid string) (int64, error)
	RevokeSessionByRefresh(ctx context.Context, refreshUuid string) (int64, error)
	// RevokeAllSessions deletes every live session of the user, so stolen
	// tokens do not survive a password change or reset.
	RevokeAllSessions(ctx context.Context, idUser uint64) error
	// RefreshSessionExists reports whether a refresh token uuid still has a
	// live (non-revoked) session.
	RefreshSessionExists(ctx context.Context, refreshUuid string) (bool, error)
	UpdatePinAndFingerprint(ctx context.Context, user *User, removePkey bool, removePin bool) error

	// StoreResetCode persists a single-use password-reset code for a user,
	// expiring after ttl. It enforces a per-user send cooldown and returns
	// ErrResetCooldown when a code was requested too recently.
	StoreResetCode(ctx context.Context, userId uint64, code string, ttl time.Duration) error
	// ConsumeResetCode verifies and invalidates the code. Wrong guesses count
	// against a small attempt budget; exceeding it invalidates the code.
	ConsumeResetCode(ctx context.Context, userId uint64, code string) error
	// DeleteResetCodes drops the pending reset code, its attempt counter and
	// its cooldown, so nothing of a deleted account outlives it in Redis.
	DeleteResetCodes(ctx context.Context, idUser uint64) error

	// Delete removes the user row. Everything it owns (categories, tags,
	// events and their links) goes with it through ON DELETE CASCADE, so
	// account deletion needs no per-table sweep. Returns a NotFound error
	// when no row matched. Redis state is cleaned separately
	// (RevokeAllSessions, DeleteResetCodes).
	Delete(ctx context.Context, idUser uint64) error

	FindSettingsByIdUser(ctx context.Context, idUser uint64) (*Settings, error)
	UpdateSettings(ctx context.Context, s *Settings, idUser uint64) error
}
