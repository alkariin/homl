package service

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

	"github.com/alkariin/homl/homl-web/helper"
	"github.com/alkariin/homl/homl-web/model"
	"golang.org/x/crypto/bcrypt"
)

type usersService struct {
	UsersRepository model.UsersRepository
}

type UserConfig struct {
	UsersRepository model.UsersRepository
}

func NewUsersService(c *UserConfig) model.UsersService {
	return &usersService{
		UsersRepository: c.UsersRepository,
	}
}

func (u *usersService) Registration(user *model.User, language *model.Language) (map[string]string, error) {
	return u.UsersRepository.Registration(user, language)
}

func (u *usersService) Login(user *model.User) (map[string]string, error) {
	// Get the existing entry present in the database for the given username
	// We create another instance of `User` to store the credentials we get from the database
	storedUser, err := u.UsersRepository.FindByUsername(user.Username)
	if err != nil {
		return nil, helper.NewAuthorization("Not authorized")
	}

	// Compare the stored hashed password, with the hashed version of the password that was received
	err = bcrypt.CompareHashAndPassword([]byte(storedUser.Password), []byte(user.Password))
	if err != nil {
		return nil, helper.NewAuthorization("Not authorized")
	}

	// Reset pin counter
	if storedUser.IsPinEnabled {
		err = u.UsersRepository.ResetPinCounter(storedUser.ID)
		if err != nil {
			return nil, err
		}
	}

	// Create access and refresh tokens
	ts, err := helper.CreateToken(storedUser.ID)
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

func (u *usersService) Logout(accessDetails *model.AccessDetails) error {
	err := u.UsersRepository.UpdateChallenge(accessDetails.UserId, nil)
	if err != nil {
		return err
	}

	deleted, delErr := u.UsersRepository.DeleteAuth(accessDetails.AccessUuid)
	if delErr != nil || deleted == 0 {
		return helper.NewInternal()
	}

	return nil
}

func (u *usersService) Refresh(ri *model.RefreshInput) (map[string]string, error) {
	// Some pre-required

	if ri.Pin != nil && ri.Signature == nil {
		return nil, helper.NewBadRequest("Signature must be provided")
	}

	// verify token
	claims, ok := helper.VerifyTokenAndRefresh(ri.Refresh_token)
	if !ok {
		return nil, helper.NewAuthorization("Not authorized")
	}

	refreshUuid, ok := claims["refresh_uuid"].(string) // convert the interface to string
	if !ok {
		return nil, helper.NewInternal()
	}
	userId, err := strconv.ParseUint(fmt.Sprintf("%.f", claims["user_id"]), 10, 64)
	if err != nil {
		return nil, err
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

		publicKey, err := helper.ParsePublicKey(*storedUser.Pkey)
		if err != nil {
			return nil, err
		}

		data := []byte(*storedUser.Challenge)

		isValid := ed25519.Verify(ed25519.PublicKey(publicKey), []byte(data), signatureDecoded)
		if !isValid {
			return nil, helper.NewInternal()
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
		return nil, helper.NewAuthorization("Not authorized")
	}
	//Create new pairs of refresh and access tokens
	ts, createErr := helper.CreateToken(userId)
	if createErr != nil {
		return nil, helper.NewStatusForbidden()
	}
	//save the tokens metadata to redis
	saveErr := u.UsersRepository.CreateAuth(userId, ts)
	if saveErr != nil {
		return nil, helper.NewStatusForbidden()
	}
	tokens := map[string]string{
		"access_token":  ts.AccessToken,
		"refresh_token": ts.RefreshToken,
	}
	return tokens, nil
}

func (u *usersService) ResetPassword(user *model.User) error {
	_, err := mail.ParseAddress(user.Username)
	if err != nil {
		return helper.NewStatusUnprocessableEntity()
	}

	// Get user id
	idUser, err := u.UsersRepository.FindIdByUsername(user.Username)
	if err != nil {
		return err
	}

	td, err := helper.CreateToken(idUser)
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

func (u *usersService) ConfirmResetPassword(user *model.User) (map[string]string, error) {
	_, err := mail.ParseAddress(user.Username)
	if err != nil {
		return nil, helper.NewStatusUnprocessableEntity()
	}

	// Get user id
	idUser, err := u.UsersRepository.FindIdByUsername(user.Username)
	if err != nil {
		return nil, err
	}

	return u.generateAndUpdatePassword(user.Password, idUser)
}

func (u *usersService) UpdatePassword(oldPassword string, newPassword string, idUser uint64) (map[string]string, error) {
	storedPassword, err := u.UsersRepository.FindPasswordById(idUser)
	if err != nil {
		return nil, err
	}

	// Compare the stored hashed password, with the hashed version of the password that was received
	err = bcrypt.CompareHashAndPassword([]byte(*storedPassword), []byte(oldPassword))
	if err != nil {
		return nil, helper.NewAuthorization("Not authorized")
	}

	return u.generateAndUpdatePassword(newPassword, idUser)
}

func (u *usersService) generateAndUpdatePassword(newPassword string, idUser uint64) (map[string]string, error) {
	// Salt and hash the password using the bcrypt algorithm
	// The second argument is the cost of hashing, which we arbitrarily set as 8 (this value can be more or less, depending on the computing power you wish to utilize)
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), 8)
	if err != nil {
		return nil, helper.NewStatusUnprocessableEntity()
	}

	// Store new password
	err = u.UsersRepository.UpdatePassword(idUser, string(hashedPassword))
	if err != nil {
		return nil, err
	}

	// Create access and refresh tokens
	ts, err := helper.CreateToken(idUser)
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
	claims, ok := helper.VerifyTokenAndRefresh(refreshToken)
	if !ok {
		return nil, helper.NewAuthorization("Refresh token expired")
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
	tokenAuth, err := helper.ExtractTokenMetadata(request)
	if err != nil {
		return 0, helper.NewAuthorization("Not authorized")
	}
	userId, err := u.UsersRepository.FetchAuth(tokenAuth)
	if err != nil {
		return 0, helper.NewAuthorization("Not authorized")
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
func (u *usersService) SecureAuth(user *model.User) (*model.UserResponse, error) {
	// Some pre-required

	if user.IsFingerprintEnabled && user.IsPinEnabled {
		return nil, helper.NewBadRequest("Pin and fingerprint cannot be both activated")
	}

	if user.IsFingerprintEnabled && user.Pin != nil {
		return nil, helper.NewBadRequest("Pin should not been provided")
	}

	if !user.IsPinEnabled && user.Pin != nil {
		return nil, helper.NewBadRequest("Pin is given but isPinEnable is false")
	}

	if user.Pin != nil && user.Pkey == nil {
		return nil, helper.NewBadRequest("Provide pkey with pin")
	}

	if user.Pkey != nil && (!user.IsPinEnabled && !user.IsFingerprintEnabled) {
		return nil, helper.NewBadRequest("Pkey should not be provided")
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

	response := &model.UserResponse{
		IsFingerprintEnabled: res.IsFingerprintEnabled,
		IsPinEnabled:         res.IsPinEnabled,
	}

	return response, err
}
