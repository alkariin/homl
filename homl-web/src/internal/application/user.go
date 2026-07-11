package application

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"log"
	"math/big"
	"net/mail"
	"time"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"golang.org/x/crypto/bcrypt"
)

// bcryptCost is the work factor used when hashing pins. 10 is the current
// bcrypt default; the low-entropy nature of a pin makes a strong factor worth it.
const bcryptCost = 10

// resetCodeTTL bounds the lifetime of a single-use password-reset code.
const resetCodeTTL = 15 * time.Minute

// UsersService is the use-case port of the User aggregate (auth included).
type UsersService interface {
	Registration(ctx context.Context, u *user.User, language *user.Language) (map[string]string, error)
	Login(ctx context.Context, u *user.User) (map[string]string, error)
	Logout(ctx context.Context, accessDetails *user.AccessDetails) error
	Refresh(ctx context.Context, refreshInput *user.RefreshInput) (map[string]string, error)
	ResetPassword(ctx context.Context, u *user.User) error
	ConfirmResetPassword(ctx context.Context, email string, code string, newPassword string) (map[string]string, error)
	UpdatePassword(ctx context.Context, oldPassword string, newPassword string, idUser uint64) (map[string]string, error)
	Challenge(ctx context.Context, refreshToken string) (*string, error)
	SecureAuth(ctx context.Context, u *user.User) (*user.UserResponse, error)
}

type usersService struct {
	UsersRepository user.Repository
	Tokens          TokenIssuer
	Mailer          Mailer
}

type UserConfig struct {
	UsersRepository user.Repository
	Tokens          TokenIssuer
	Mailer          Mailer
}

func NewUsersService(c *UserConfig) UsersService {
	return &usersService{
		UsersRepository: c.UsersRepository,
		Tokens:          c.Tokens,
		Mailer:          c.Mailer,
	}
}

func (u *usersService) Registration(ctx context.Context, usr *user.User, language *user.Language) (map[string]string, error) {
	// Hash here so no persistence layer ever sees the plaintext password
	// (password changes already hash in this layer, via
	// generateAndUpdatePassword).
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(usr.Password), user.PasswordBcryptCost)
	if err != nil {
		return nil, err
	}
	usr.Password = string(hashedPassword)

	err = u.UsersRepository.Registration(ctx, usr, language)
	if err != nil {
		return nil, err
	}

	// The account is committed at this point; if token creation fails the
	// user simply logs in afterwards.
	return u.createSession(ctx, usr.ID)
}

func (u *usersService) Login(ctx context.Context, user *user.User) (map[string]string, error) {
	// Get the existing entry present in the database for the given username
	// We create another instance of `User` to store the credentials we get from the database
	storedUser, err := u.UsersRepository.FindByUsername(ctx, user.Username)
	if err != nil {
		return nil, apperror.NewAuthorization("Not authorized")
	}

	// Compare the stored hashed password, with the hashed version of the password that was received
	err = bcrypt.CompareHashAndPassword([]byte(storedUser.Password), []byte(user.Password))
	if err != nil {
		return nil, apperror.NewAuthorization("Not authorized")
	}

	// Reset pin counter
	if storedUser.IsPinEnabled {
		err = u.UsersRepository.ResetPinCounter(ctx, storedUser.ID)
		if err != nil {
			return nil, err
		}
	}

	return u.createSession(ctx, storedUser.ID)
}

// createSession mints a fresh access/refresh token pair and stores its
// metadata in the auth store.
func (u *usersService) createSession(ctx context.Context, idUser uint64) (map[string]string, error) {
	ts, err := u.Tokens.CreateToken(idUser)
	if err != nil {
		return nil, err
	}
	err = u.UsersRepository.CreateAuth(ctx, idUser, ts)
	if err != nil {
		return nil, err
	}
	tokens := map[string]string{
		"access_token":  ts.AccessToken,
		"refresh_token": ts.RefreshToken,
	}
	return tokens, nil
}

func (u *usersService) Logout(ctx context.Context, accessDetails *user.AccessDetails) error {
	err := u.UsersRepository.UpdateChallenge(ctx, accessDetails.UserId, nil)
	if err != nil {
		return err
	}

	// Revoke the whole pair: leaving the refresh token alive would let a
	// "logged-out" session resurrect itself through /refresh for months.
	deleted, delErr := u.UsersRepository.RevokeSessionByAccess(ctx, accessDetails.AccessUuid)
	if delErr != nil || deleted == 0 {
		return apperror.NewInternal()
	}

	return nil
}

func (u *usersService) Refresh(ctx context.Context, ri *user.RefreshInput) (map[string]string, error) {
	// Some pre-required

	if ri.Pin != nil && ri.Signature == nil {
		return nil, apperror.NewBadRequest("Signature must be provided")
	}

	// verify token
	rd, err := u.Tokens.VerifyRefresh(ri.Refresh_token)
	if err != nil {
		return nil, apperror.NewAuthorization("Not authorized")
	}

	// Enforce the second factor server-side: a valid refresh token alone must
	// not be enough once the account has pin or fingerprint enabled, otherwise
	// the extra factor is only a client-side illusion.
	secureUser, err := u.UsersRepository.FindById(ctx, rd.UserId)
	if err != nil {
		return nil, apperror.NewAuthorization("Not authorized")
	}
	if secureUser.IsPinEnabled && ri.Pin == nil {
		return nil, apperror.NewAuthorization("Pin must be provided")
	}
	if secureUser.IsFingerprintEnabled && ri.Signature == nil {
		return nil, apperror.NewAuthorization("Signature must be provided")
	}

	// Verification of signature
	signature := ri.Signature
	if signature != nil {
		signatureDecoded, err := base64.StdEncoding.DecodeString(*signature)
		if err != nil {
			// A malformed signature is a failed authentication, not a server error.
			return nil, apperror.NewAuthorization("Not authorized")
		}

		storedUser, err := u.UsersRepository.FindPkeyAndChallengeById(ctx, rd.UserId)
		if err != nil {
			return nil, err
		}

		if storedUser.Pkey == nil || storedUser.Challenge == nil {
			return nil, apperror.NewAuthorization("Not authorized")
		}

		// Consume the challenge before verifying so it can be used at most once,
		// even if verification fails. This prevents replaying a captured
		// challenge/signature pair.
		if err := u.UsersRepository.UpdateChallenge(ctx, rd.UserId, nil); err != nil {
			return nil, err
		}

		publicKey, err := base64.StdEncoding.DecodeString(*storedUser.Pkey)
		if err != nil {
			return nil, err
		}

		data := []byte(*storedUser.Challenge)

		isValid := ed25519.Verify(ed25519.PublicKey(publicKey), []byte(data), signatureDecoded)
		if !isValid {
			return nil, apperror.NewAuthorization("Not authorized")
		}
	}

	// Verification of pin
	if ri.Pin != nil {
		err = u.UsersRepository.CheckPin(ctx, rd.UserId, *ri.Pin)
		if err != nil {
			return nil, err
		}
	}

	// Rotate: revoke the previous session pair (refresh + its access token).
	// deleted == 0 means the refresh token was already used or revoked.
	deleted, delErr := u.UsersRepository.RevokeSessionByRefresh(ctx, rd.RefreshUuid)
	if delErr != nil || deleted == 0 { // if any goes wrong
		return nil, apperror.NewAuthorization("Not authorized")
	}
	//Create new pairs of refresh and access tokens
	tokens, err := u.createSession(ctx, rd.UserId)
	if err != nil {
		return nil, apperror.NewStatusForbidden()
	}
	return tokens, nil
}

func (u *usersService) ResetPassword(ctx context.Context, usr *user.User) error {
	if _, err := mail.ParseAddress(usr.Username); err != nil {
		return apperror.NewStatusUnprocessableEntity()
	}

	// Always return success regardless of whether the email is known, so the
	// endpoint cannot be used to enumerate accounts.
	idUser, err := u.UsersRepository.FindIdByUsername(ctx, usr.Username)
	if err != nil {
		return nil
	}

	// Issue a short-lived single-use 6-digit code, stored server-side so it
	// can be revoked on first use and guess-limited.
	code, err := generateResetCode()
	if err != nil {
		log.Printf("reset password: could not generate code: %v", err)
		return nil
	}
	if err := u.UsersRepository.StoreResetCode(ctx, idUser, code, resetCodeTTL); err != nil {
		if errors.Is(err, user.ErrResetCooldown) {
			log.Printf("reset password: code for %s requested too recently", usr.Username)
		} else {
			log.Printf("reset password: could not store code: %v", err)
		}
		return nil
	}

	// Send the email in the user's stored language, falling back to English
	// when the settings cannot be loaded.
	language := user.Language("en")
	if settings, err := u.UsersRepository.FindSettingsByIdUser(ctx, idUser); err == nil {
		language = settings.Language
	}

	if err := u.Mailer.SendPasswordResetCode(usr.Username, code, language); err != nil {
		// Do not leak the failure to the caller (would reveal the address exists).
		log.Printf("reset password: could not send email: %v", err)
	}

	return nil
}

// generateResetCode returns a uniformly random 6-digit code.
func generateResetCode() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1_000_000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n), nil
}

// ConfirmResetPassword sets a new password for the user owning the emailed
// reset code. The code is consumed on use, so it works at most once. Every
// failure maps to the same error so the endpoint cannot enumerate accounts.
func (u *usersService) ConfirmResetPassword(ctx context.Context, email string, code string, newPassword string) (map[string]string, error) {
	idUser, err := u.UsersRepository.FindIdByUsername(ctx, email)
	if err != nil {
		return nil, apperror.NewResetCodeInvalid()
	}
	if err := u.UsersRepository.ConsumeResetCode(ctx, idUser, code); err != nil {
		return nil, apperror.NewResetCodeInvalid()
	}
	return u.generateAndUpdatePassword(ctx, newPassword, idUser)
}

func (u *usersService) UpdatePassword(ctx context.Context, oldPassword string, newPassword string, idUser uint64) (map[string]string, error) {
	storedPassword, err := u.UsersRepository.FindPasswordById(ctx, idUser)
	if err != nil {
		return nil, err
	}

	// Compare the stored hashed password, with the hashed version of the password that was received
	err = bcrypt.CompareHashAndPassword([]byte(*storedPassword), []byte(oldPassword))
	if err != nil {
		return nil, apperror.NewAuthorization("Not authorized")
	}

	return u.generateAndUpdatePassword(ctx, newPassword, idUser)
}

func (u *usersService) generateAndUpdatePassword(ctx context.Context, newPassword string, idUser uint64) (map[string]string, error) {
	// Salt and hash the password using the bcrypt algorithm.
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), user.PasswordBcryptCost)
	if err != nil {
		return nil, apperror.NewStatusUnprocessableEntity()
	}

	// Store new password
	err = u.UsersRepository.UpdatePassword(ctx, idUser, string(hashedPassword))
	if err != nil {
		return nil, err
	}

	// A credential rotation invalidates every existing session: a stolen
	// refresh token must not survive the password change that was meant to
	// evict the thief. The fresh session below is minted afterwards.
	if err := u.UsersRepository.RevokeAllSessions(ctx, idUser); err != nil {
		return nil, err
	}

	return u.createSession(ctx, idUser)
}

func (u *usersService) Challenge(ctx context.Context, refreshToken string) (*string, error) {
	// 32 random bytes (256 bits) rendered as URL-safe base64, untruncated, so
	// the challenge keeps its full entropy.
	bytes := make([]byte, 32)
	_, err := rand.Read(bytes)
	if err != nil {
		return nil, err
	}
	challenge := base64.RawURLEncoding.EncodeToString(bytes)

	// Store the challenge
	rd, err := u.Tokens.VerifyRefresh(refreshToken)
	if err != nil {
		return nil, apperror.NewAuthorization("Refresh token expired")
	}

	// A signed-but-revoked refresh token (logout, rotation, password change)
	// must not be able to keep minting challenges.
	alive, err := u.UsersRepository.RefreshSessionExists(ctx, rd.RefreshUuid)
	if err != nil {
		return nil, err
	}
	if !alive {
		return nil, apperror.NewAuthorization("Not authorized")
	}

	err = u.UsersRepository.UpdateChallenge(ctx, rd.UserId, &challenge)
	if err != nil {
		return nil, err
	}

	return &challenge, nil
}

/** input:
 * {
 *   isFingerprintEnabled: bool,
 *   isPinEnabled: bool,
 *   pin?: string,
 *   pkey?: string
 * }
 */
func (u *usersService) SecureAuth(ctx context.Context, usr *user.User) (*user.UserResponse, error) {
	// Some pre-required

	if usr.IsFingerprintEnabled && usr.IsPinEnabled {
		return nil, apperror.NewBadRequest("Pin and fingerprint cannot be both activated")
	}

	if usr.IsFingerprintEnabled && usr.Pin != nil {
		return nil, apperror.NewBadRequest("Pin should not been provided")
	}

	if !usr.IsPinEnabled && usr.Pin != nil {
		return nil, apperror.NewBadRequest("Pin is given but isPinEnable is false")
	}

	if usr.Pin != nil && usr.Pkey == nil {
		return nil, apperror.NewBadRequest("Provide pkey with pin")
	}

	if usr.Pkey != nil && (!usr.IsPinEnabled && !usr.IsFingerprintEnabled) {
		return nil, apperror.NewBadRequest("Pkey should not be provided")
	}

	// Hash the pin before it ever reaches the database. A pin is a low-entropy
	// secret, so plaintext storage would expose every pin on a DB leak.
	if usr.Pin != nil {
		hashedPin, err := bcrypt.GenerateFromPassword([]byte(*usr.Pin), bcryptCost)
		if err != nil {
			return nil, apperror.NewStatusUnprocessableEntity()
		}
		hashedPinStr := string(hashedPin)
		usr.Pin = &hashedPinStr
	}

	// reactions

	removePin := false
	if !usr.IsPinEnabled {
		removePin = true
	}

	removePkey := false
	if !usr.IsFingerprintEnabled && !usr.IsPinEnabled {
		removePkey = true
	}

	// request
	if err := u.UsersRepository.UpdatePinAndFingerprint(ctx, usr, removePkey, removePin); err != nil {
		return nil, err
	}

	// Get new values and send them back
	res, err := u.UsersRepository.FindById(ctx, usr.ID)
	if err != nil {
		return nil, err
	}

	response := &user.UserResponse{
		IsFingerprintEnabled: res.IsFingerprintEnabled,
		IsPinEnabled:         res.IsPinEnabled,
	}

	return response, nil
}
