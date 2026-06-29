package controller

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/homl/homl-web/helper"
	"github.com/alkariin/homl/homl-web/model"
)

var usernameValidation = "required,email"
var passwordValidation = "required,min=8"
var languageValidation = "required,eq=fr|eq=de|eq=en"

/** input:
 * {
 *   username: string,
 *	 password: string,
 *   language: string // "fr" or "de"
 * }
 */
func (h *Handler) Registration(c *gin.Context) {
	type RegistrationInput struct {
		Username string         `json:"username"`
		Password string         `json:"password"`
		Language model.Language `json:"language"`
	}

	// Parse and decode the request body into a new `User` instance
	var body RegistrationInput
	err := c.ShouldBindJSON(&body)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}

	v1 := helper.GinInputParams{Field: body.Username, Validation: usernameValidation}
	v2 := helper.GinInputParams{Field: body.Password, Validation: passwordValidation}
	v3 := helper.GinInputParams{Field: body.Language, Validation: languageValidation}
	if helper.CheckGinInput(v1, v2, v3) {
		helper.SendGinError(c, helper.NewStatusUnprocessableEntity())
		return
	}

	user := model.User{
		Username: body.Username,
		Password: body.Password,
	}

	tokens, err := h.UsersService.Registration(&user, &body.Language)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, tokens)
}

/** input:
 * {
 *   username: string,
 *	 password: string
 * }
 */
func (h *Handler) Login(c *gin.Context) {
	// Parse and decode the request body into a new `User` instance
	var user model.User
	err := c.ShouldBindJSON(&user)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}

	v1 := helper.GinInputParams{Field: user.Username, Validation: usernameValidation}
	v2 := helper.GinInputParams{Field: user.Password, Validation: passwordValidation}
	if helper.CheckGinInput(v1, v2) {
		helper.SendGinError(c, helper.NewStatusUnprocessableEntity())
		return
	}

	tokens, err := h.UsersService.Login(&user)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	// The default 200 status is sent
	c.JSON(http.StatusOK, tokens)
}

/** input:
 * {}
 */
func (h *Handler) Logout(c *gin.Context) {
	au, err := helper.ExtractTokenMetadata(c.Request)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewAuthorization("Something went wrong when reading token"))
		return
	}

	err = h.UsersService.Logout(au)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/** input:
 * {
 *   refresh_token: string,
 *   signature?: string,
 *   pin?: string
 * }
 */
func (h *Handler) Refresh(c *gin.Context) {
	var input model.RefreshInput
	err := c.ShouldBindJSON(&input)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}
	refreshToken := input.Refresh_token
	if refreshToken == "" {
		helper.SendGinError(c, helper.NewAuthorization("Refresh token expired"))
		return
	}

	tokens, err := h.UsersService.Refresh(&input)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.JSON(http.StatusCreated, tokens)
}

/** input:
 * {
 *   username: string
 * }
 */
func (h *Handler) ResetPassword(c *gin.Context) {
	var user model.User
	err := c.ShouldBindJSON(&user)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}

	v1 := helper.GinInputParams{Field: user.Username, Validation: usernameValidation}
	if helper.CheckGinInput(v1) {
		helper.SendGinError(c, helper.NewStatusUnprocessableEntity())
		return
	}

	err = h.UsersService.ResetPassword(&user)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/** input:
 * {
 *   username: string,
 *   password: string
 * }
 */
func (h *Handler) ConfirmResetPassword(c *gin.Context) {
	var user model.User
	err := c.ShouldBindJSON(&user)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}

	v1 := helper.GinInputParams{Field: user.Username, Validation: usernameValidation}
	if helper.CheckGinInput(v1) {
		helper.SendGinError(c, helper.NewStatusUnprocessableEntity())
		return
	}

	tokens, err := h.UsersService.ConfirmResetPassword(&user)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, tokens)
}

/** input:
 * {
 *   oldPassword: string,
 *   newPassword: string
 * }
 */
func (h *Handler) UpdatePassword(c *gin.Context) {
	var userPassword model.UserPassword
	err := c.ShouldBindJSON(&userPassword)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}

	v1 := helper.GinInputParams{Field: userPassword.OldPassword, Validation: passwordValidation}
	v2 := helper.GinInputParams{Field: userPassword.NewPassword, Validation: passwordValidation}
	if helper.CheckGinInput(v1, v2) {
		helper.SendGinError(c, helper.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	tokens, err := h.UsersService.UpdatePassword(userPassword.OldPassword, userPassword.NewPassword, idUser)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, tokens)
}

/** input:
 * {
 *   refresh_token: string
 * }
 */
func (h *Handler) Challenge(c *gin.Context) {
	mapToken := map[string]string{}
	err := c.ShouldBindJSON(&mapToken)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}
	refreshToken := mapToken["refresh_token"]
	if refreshToken == "" {
		helper.SendGinError(c, helper.NewAuthorization("Refresh token expired"))
		return
	}

	challenge, err := h.UsersService.Challenge(refreshToken)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, *challenge)
}

/** input:
 * {
 *   isFingerprintEnabled: bool,
 *   isPinEnabled: bool,
 *   pin?: string,
 *   pkey?: string
 * }
 */
func (h *Handler) SecureAuth(c *gin.Context) {
	var user model.User

	err := c.ShouldBindJSON(&user)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	user.ID = idUser

	res, err := h.UsersService.SecureAuth(&user)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, *res)
}
