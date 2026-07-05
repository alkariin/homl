package web

import (
	"net/http"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/gin-gonic/gin"
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
func (h *UserHandler) Registration(c *gin.Context) {
	type RegistrationInput struct {
		Username string        `json:"username"`
		Password string        `json:"password"`
		Language user.Language `json:"language"`
	}

	// Parse and decode the request body into a new `User` instance
	var body RegistrationInput
	err := c.ShouldBindJSON(&body)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	v1 := GinInputParams{Field: body.Username, Validation: usernameValidation}
	v2 := GinInputParams{Field: body.Password, Validation: passwordValidation}
	v3 := GinInputParams{Field: body.Language, Validation: languageValidation}
	if CheckGinInput(v1, v2, v3) {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	user := user.User{
		Username: body.Username,
		Password: body.Password,
	}

	tokens, err := h.UsersService.Registration(&user, &body.Language)
	if err != nil {
		SendGinError(c, err)
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
func (h *UserHandler) Login(c *gin.Context) {
	// Parse and decode the request body into a new `User` instance
	var user user.User
	err := c.ShouldBindJSON(&user)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	v1 := GinInputParams{Field: user.Username, Validation: usernameValidation}
	v2 := GinInputParams{Field: user.Password, Validation: passwordValidation}
	if CheckGinInput(v1, v2) {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	tokens, err := h.UsersService.Login(&user)
	if err != nil {
		SendGinError(c, err)
		return
	}

	// The default 200 status is sent
	c.JSON(http.StatusOK, tokens)
}

/** input:
 * {}
 */
func (h *UserHandler) Logout(c *gin.Context) {
	au, err := h.Tokens.ExtractAccessDetails(c.Request)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewAuthorization("Something went wrong when reading token"))
		return
	}

	err = h.UsersService.Logout(au)
	if err != nil {
		SendGinError(c, err)
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
func (h *UserHandler) Refresh(c *gin.Context) {
	var input user.RefreshInput
	err := c.ShouldBindJSON(&input)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}
	refreshToken := input.Refresh_token
	if refreshToken == "" {
		SendGinError(c, apperror.NewAuthorization("Refresh token expired"))
		return
	}

	tokens, err := h.UsersService.Refresh(&input)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.JSON(http.StatusCreated, tokens)
}

/** input:
 * {
 *   username: string
 * }
 */
func (h *UserHandler) ResetPassword(c *gin.Context) {
	var user user.User
	err := c.ShouldBindJSON(&user)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	v1 := GinInputParams{Field: user.Username, Validation: usernameValidation}
	if CheckGinInput(v1) {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	err = h.UsersService.ResetPassword(&user)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/** input:
 * {
 *   password: string
 * }
 */
func (h *UserHandler) ConfirmResetPassword(c *gin.Context) {
	var user user.User
	err := c.ShouldBindJSON(&user)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	v1 := GinInputParams{Field: user.Password, Validation: passwordValidation}
	if CheckGinInput(v1) {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	// The reset token is a dedicated single-use credential carried in the
	// Authorization header (never an access token). The service resolves and
	// revokes it, so the account being reset is bound to the token, not the body.
	resetToken := bearerToken(c.Request)
	if resetToken == "" {
		SendGinError(c, apperror.NewAuthorization("Not authorized"))
		return
	}

	tokens, err := h.UsersService.ConfirmResetPassword(user.Password, resetToken)
	if err != nil {
		SendGinError(c, err)
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
func (h *UserHandler) UpdatePassword(c *gin.Context) {
	var userPassword user.UserPassword
	err := c.ShouldBindJSON(&userPassword)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	v1 := GinInputParams{Field: userPassword.OldPassword, Validation: passwordValidation}
	v2 := GinInputParams{Field: userPassword.NewPassword, Validation: passwordValidation}
	if CheckGinInput(v1, v2) {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	tokens, err := h.UsersService.UpdatePassword(userPassword.OldPassword, userPassword.NewPassword, idUser)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, tokens)
}

/** input:
 * {
 *   refresh_token: string
 * }
 */
func (h *UserHandler) Challenge(c *gin.Context) {
	mapToken := map[string]string{}
	err := c.ShouldBindJSON(&mapToken)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}
	refreshToken := mapToken["refresh_token"]
	if refreshToken == "" {
		SendGinError(c, apperror.NewAuthorization("Refresh token expired"))
		return
	}

	challenge, err := h.UsersService.Challenge(refreshToken)
	if err != nil {
		SendGinError(c, err)
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
func (h *UserHandler) SecureAuth(c *gin.Context) {
	var user user.User

	err := c.ShouldBindJSON(&user)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	user.ID = idUser

	res, err := h.UsersService.SecureAuth(&user)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, *res)
}

// Handler wires the auth/user HTTP endpoints to their service.
type UserHandler struct {
	UsersService application.UsersService
	Tokens       TokenParser
}
