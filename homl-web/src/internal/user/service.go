package user

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"net/http"
	"net/mail"
	"net/smtp"
	"os"
	"strconv"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/shared"
	"golang.org/x/crypto/bcrypt"
)

// bcryptCost is the work factor used when hashing pins. 10 is the current
// bcrypt default; the low-entropy nature of a pin makes a strong factor worth it.
const bcryptCost = 10

type usersService struct {
	UsersRepository domain.UsersRepository
}

type UserConfig struct {
	UsersRepository domain.UsersRepository
}

func NewUsersService(c *UserConfig) domain.UsersService {
	return &usersService{
		UsersRepository: c.UsersRepository,
	}
}

func (u *usersService) Registration(user *domain.User, language *domain.Language) (map[string]string, error) {
	return u.UsersRepository.Registration(user, language)
}

func (u *usersService) Login(user *domain.User) (map[string]string, error) {
	// Get the existing entry present in the database for the given username
	// We create another instance of `User` to store the credentials we get from the database
	storedUser, err := u.UsersRepository.FindByUsername(user.Username)
	if err != nil {
		return nil, shared.NewAuthorization("Not authorized")
	}

	// Compare the stored hashed password, with the hashed version of the password that was received
	err = bcrypt.CompareHashAndPassword([]byte(storedUser.Password), []byte(user.Password))
	if err != nil {
		return nil, shared.NewAuthorization("Not authorized")
	}

	// Reset pin counter
	if storedUser.IsPinEnabled {
		err = u.UsersRepository.ResetPinCounter(storedUser.ID)
		if err != nil {
			return nil, err
		}
	}

	// Create access and refresh tokens
	ts, err := shared.CreateToken(storedUser.ID)
	if err != nil {
		return nil, err
	}
	err = u.UsersRepository.CreateAuth(storedUser.ID, ts)
	if err != nil {
		return nil, err
	}
	tokens := map[string]string{
		"access_token":  ts.AccessToken,
		"refresh_token": ts.RefreshToken,
	}
	return tokens, nil
}

func (u *usersService) Logout(accessDetails *domain.AccessDetails) error {
	err := u.UsersRepository.UpdateChallenge(accessDetails.UserId, nil)
	if err != nil {
		return err
	}

	deleted, delErr := u.UsersRepository.DeleteAuth(accessDetails.AccessUuid)
	if delErr != nil || deleted == 0 {
		return shared.NewInternal()
	}

	return nil
}

func (u *usersService) Refresh(ri *domain.RefreshInput) (map[string]string, error) {
	// Some pre-required

	if ri.Pin != nil && ri.Signature == nil {
		return nil, shared.NewBadRequest("Signature must be provided")
	}

	// verify token
	claims, ok := shared.VerifyTokenAndRefresh(ri.Refresh_token)
	if !ok {
		return nil, shared.NewAuthorization("Not authorized")
	}

	refreshUuid, ok := claims["refresh_uuid"].(string) // convert the interface to string
	if !ok {
		return nil, shared.NewInternal()
	}
	userId, err := strconv.ParseUint(fmt.Sprintf("%.f", claims["user_id"]), 10, 64)
	if err != nil {
		return nil, err
	}

	// Enforce the second factor server-side: a valid refresh token alone must
	// not be enough once the account has pin or fingerprint enabled, otherwise
	// the extra factor is only a client-side illusion.
	secureUser, err := u.UsersRepository.FindById(userId)
	if err != nil {
		return nil, shared.NewAuthorization("Not authorized")
	}
	if secureUser.IsPinEnabled && ri.Pin == nil {
		return nil, shared.NewAuthorization("Pin must be provided")
	}
	if secureUser.IsFingerprintEnabled && ri.Signature == nil {
		return nil, shared.NewAuthorization("Signature must be provided")
	}

	// Verification of signature
	signature := ri.Signature
	if signature != nil {
		signatureDecoded, err := base64.StdEncoding.DecodeString(*signature)
		if err != nil {
			return nil, err
		}

		storedUser, err := u.UsersRepository.FindPkeyAndChallengeById(userId)
		if err != nil {
			return nil, err
		}

		if storedUser.Pkey == nil || storedUser.Challenge == nil {
			return nil, shared.NewAuthorization("Not authorized")
		}

		// Consume the challenge before verifying so it can be used at most once,
		// even if verification fails. This prevents replaying a captured
		// challenge/signature pair.
		if err := u.UsersRepository.UpdateChallenge(userId, nil); err != nil {
			return nil, err
		}

		publicKey, err := shared.ParsePublicKey(*storedUser.Pkey)
		if err != nil {
			return nil, err
		}

		data := []byte(*storedUser.Challenge)

		isValid := ed25519.Verify(ed25519.PublicKey(publicKey), []byte(data), signatureDecoded)
		if !isValid {
			return nil, shared.NewAuthorization("Not authorized")
		}
	}

	// Verification of pin
	if ri.Pin != nil {
		err = u.UsersRepository.CheckPin(userId, *ri.Pin)
		if err != nil {
			return nil, err
		}
	}

	//Delete the previous Refresh Token
	deleted, delErr := u.UsersRepository.DeleteAuth(refreshUuid)
	if delErr != nil || deleted == 0 { // if any goes wrong
		return nil, shared.NewAuthorization("Not authorized")
	}
	//Create new pairs of refresh and access tokens
	ts, createErr := shared.CreateToken(userId)
	if createErr != nil {
		return nil, shared.NewStatusForbidden()
	}
	//save the tokens metadata to redis
	saveErr := u.UsersRepository.CreateAuth(userId, ts)
	if saveErr != nil {
		return nil, shared.NewStatusForbidden()
	}
	tokens := map[string]string{
		"access_token":  ts.AccessToken,
		"refresh_token": ts.RefreshToken,
	}
	return tokens, nil
}

func (u *usersService) ResetPassword(user *domain.User) error {
	_, err := mail.ParseAddress(user.Username)
	if err != nil {
		return shared.NewStatusUnprocessableEntity()
	}

	// Get user id
	idUser, err := u.UsersRepository.FindIdByUsername(user.Username)
	if err != nil {
		return err
	}

	td, err := shared.CreateToken(idUser)
	if err != nil {
		return err
	}

	link := os.Getenv("HOST") + "/reset?email=" + user.Username + "&token=" + td.AccessToken

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
func (u *usersService) ConfirmResetPassword(newPassword string, idUser uint64) (map[string]string, error) {
	return u.generateAndUpdatePassword(newPassword, idUser)
}

func (u *usersService) UpdatePassword(oldPassword string, newPassword string, idUser uint64) (map[string]string, error) {
	storedPassword, err := u.UsersRepository.FindPasswordById(idUser)
	if err != nil {
		return nil, err
	}

	// Compare the stored hashed password, with the hashed version of the password that was received
	err = bcrypt.CompareHashAndPassword([]byte(*storedPassword), []byte(oldPassword))
	if err != nil {
		return nil, shared.NewAuthorization("Not authorized")
	}

	return u.generateAndUpdatePassword(newPassword, idUser)
}

func (u *usersService) generateAndUpdatePassword(newPassword string, idUser uint64) (map[string]string, error) {
	// Salt and hash the password using the bcrypt algorithm
	// The second argument is the cost of hashing, which we arbitrarily set as 8 (this value can be more or less, depending on the computing power you wish to utilize)
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), 8)
	if err != nil {
		return nil, shared.NewStatusUnprocessableEntity()
	}

	// Store new password
	err = u.UsersRepository.UpdatePassword(idUser, string(hashedPassword))
	if err != nil {
		return nil, err
	}

	// Create access and refresh tokens
	ts, err := shared.CreateToken(idUser)
	if err != nil {
		return nil, err
	}
	err = u.UsersRepository.CreateAuth(idUser, ts)
	if err != nil {
		return nil, err
	}
	tokens := map[string]string{
		"access_token":  ts.AccessToken,
		"refresh_token": ts.RefreshToken,
	}
	return tokens, nil
}

func (u *usersService) Challenge(refreshToken string) (*string, error) {
	length := 10
	bytes := make([]byte, length)
	_, err := rand.Read(bytes)
	if err != nil {
		return nil, err
	}
	randomString := base64.URLEncoding.EncodeToString(bytes)
	challenge := randomString[:length]

	// Store the challenge
	claims, ok := shared.VerifyTokenAndRefresh(refreshToken)
	if !ok {
		return nil, shared.NewAuthorization("Refresh token expired")
	}

	userId, err := strconv.ParseUint(fmt.Sprintf("%.f", claims["user_id"]), 10, 64)
	if err != nil {
		return nil, err
	}

	err = u.UsersRepository.UpdateChallenge(userId, &challenge)
	if err != nil {
		return nil, err
	}

	return &challenge, nil
}

func (u *usersService) GetUserIdFromToken(request *http.Request) (uint64, error) {
	tokenAuth, err := shared.ExtractTokenMetadata(request)
	if err != nil {
		return 0, shared.NewAuthorization("Not authorized")
	}
	userId, err := u.UsersRepository.FetchAuth(tokenAuth)
	if err != nil {
		return 0, shared.NewAuthorization("Not authorized")
	}
	return userId, nil
}

/** input:
 * {
 *   isFingerprintEnabled: bool,
 *   isPinEnabled: bool,
 *   pin?: string,
 *   pkey?: string
 * }
 */
func (u *usersService) SecureAuth(user *domain.User) (*domain.UserResponse, error) {
	// Some pre-required

	if user.IsFingerprintEnabled && user.IsPinEnabled {
		return nil, shared.NewBadRequest("Pin and fingerprint cannot be both activated")
	}

	if user.IsFingerprintEnabled && user.Pin != nil {
		return nil, shared.NewBadRequest("Pin should not been provided")
	}

	if !user.IsPinEnabled && user.Pin != nil {
		return nil, shared.NewBadRequest("Pin is given but isPinEnable is false")
	}

	if user.Pin != nil && user.Pkey == nil {
		return nil, shared.NewBadRequest("Provide pkey with pin")
	}

	if user.Pkey != nil && (!user.IsPinEnabled && !user.IsFingerprintEnabled) {
		return nil, shared.NewBadRequest("Pkey should not be provided")
	}

	// Hash the pin before it ever reaches the database. A pin is a low-entropy
	// secret, so plaintext storage would expose every pin on a DB leak.
	if user.Pin != nil {
		hashedPin, err := bcrypt.GenerateFromPassword([]byte(*user.Pin), bcryptCost)
		if err != nil {
			return nil, shared.NewStatusUnprocessableEntity()
		}
		hashedPinStr := string(hashedPin)
		user.Pin = &hashedPinStr
	}

	// reactions

	removePin := false
	if !user.IsPinEnabled {
		removePin = true
	}

	removePkey := false
	if !user.IsFingerprintEnabled && !user.IsPinEnabled {
		removePkey = true
	}

	// request
	u.UsersRepository.UpdatePinAndFingerprint(user, removePkey, removePin)

	// Get new values and send them back
	res, err := u.UsersRepository.FindById(user.ID)

	response := &domain.UserResponse{
		IsFingerprintEnabled: res.IsFingerprintEnabled,
		IsPinEnabled:         res.IsPinEnabled,
	}

	return response, err
}
