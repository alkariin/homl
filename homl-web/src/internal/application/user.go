package application

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"net/mail"
	"net/smtp"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"golang.org/x/crypto/bcrypt"
)

// bcryptCost is the work factor used when hashing pins. 10 is the current
// bcrypt default; the low-entropy nature of a pin makes a strong factor worth it.
const bcryptCost = 10

// UsersService is the use-case port of the User aggregate (auth included).
type UsersService interface {
	Registration(ctx context.Context, u *user.User, language *user.Language) (map[string]string, error)
	Login(ctx context.Context, u *user.User) (map[string]string, error)
	Logout(ctx context.Context, accessDetails *user.AccessDetails) error
	Refresh(ctx context.Context, refreshInput *user.RefreshInput) (map[string]string, error)
	ResetPassword(ctx context.Context, u *user.User) error
	ConfirmResetPassword(ctx context.Context, newPassword string, idUser uint64) (map[string]string, error)
	UpdatePassword(ctx context.Context, oldPassword string, newPassword string, idUser uint64) (map[string]string, error)
	Challenge(ctx context.Context, refreshToken string) (*string, error)
	SecureAuth(ctx context.Context, u *user.User) (*user.UserResponse, error)
}

type usersService struct {
	UsersRepository user.Repository
	Tokens          TokenIssuer
	Host            string // public host used in password-reset links
}

type UserConfig struct {
	UsersRepository user.Repository
	Tokens          TokenIssuer
	Host            string
}

func NewUsersService(c *UserConfig) UsersService {
	return &usersService{
		UsersRepository: c.UsersRepository,
		Tokens:          c.Tokens,
		Host:            c.Host,
	}
}

func (u *usersService) Registration(ctx context.Context, usr *user.User, language *user.Language) (map[string]string, error) {
	err := u.UsersRepository.Registration(ctx, usr, language)
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

	deleted, delErr := u.UsersRepository.DeleteAuth(ctx, accessDetails.AccessUuid)
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
			return nil, err
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

	//Delete the previous Refresh Token
	deleted, delErr := u.UsersRepository.DeleteAuth(ctx, rd.RefreshUuid)
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

func (u *usersService) ResetPassword(ctx context.Context, user *user.User) error {
	_, err := mail.ParseAddress(user.Username)
	if err != nil {
		return apperror.NewStatusUnprocessableEntity()
	}

	// Get user id
	idUser, err := u.UsersRepository.FindIdByUsername(ctx, user.Username)
	if err != nil {
		return err
	}

	td, err := u.Tokens.CreateToken(idUser)
	if err != nil {
		return err
	}

	link := u.Host + "/reset?email=" + user.Username + "&token=" + td.AccessToken

	// Sender data.
	from := "no_reply@homl.ch"
	password := "<Email Password>"

	// Receiver email address.
	to := []string{
		user.Username,
	}

	// smtp server configuration.
	smtpHost := "smtp.gmail.com"
	smtpPort := "587"

	// Message.
	message := []byte("Click here to reset your password: " + link)

	// Authentication.
	auth := smtp.PlainAuth("", from, password, smtpHost)

	// Sending email.
	return smtp.SendMail(smtpHost+":"+smtpPort, auth, from, to, message)
}

// ConfirmResetPassword sets a new password for the user identified by idUser,
// which the handler derives from the reset token. The target account is never
// taken from the request body, so a valid token cannot be used to reset another
// user's password.
func (u *usersService) ConfirmResetPassword(ctx context.Context, newPassword string, idUser uint64) (map[string]string, error) {
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
	// Salt and hash the password using the bcrypt algorithm
	// The second argument is the cost of hashing, which we arbitrarily set as 8 (this value can be more or less, depending on the computing power you wish to utilize)
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), 8)
	if err != nil {
		return nil, apperror.NewStatusUnprocessableEntity()
	}

	// Store new password
	err = u.UsersRepository.UpdatePassword(ctx, idUser, string(hashedPassword))
	if err != nil {
		return nil, err
	}

	return u.createSession(ctx, idUser)
}

func (u *usersService) Challenge(ctx context.Context, refreshToken string) (*string, error) {
	length := 10
	bytes := make([]byte, length)
	_, err := rand.Read(bytes)
	if err != nil {
		return nil, err
	}
	randomString := base64.URLEncoding.EncodeToString(bytes)
	challenge := randomString[:length]

	// Store the challenge
	rd, err := u.Tokens.VerifyRefresh(refreshToken)
	if err != nil {
		return nil, apperror.NewAuthorization("Refresh token expired")
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
