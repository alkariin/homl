package user

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/shared"
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
		Username string          `json:"username"`
		Password string          `json:"password"`
		Language domain.Language `json:"language"`
	}

	// Parse and decode the request body into a new `User` instance
	var body RegistrationInput
	err := c.ShouldBindJSON(&body)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	v1 := shared.GinInputParams{Field: body.Username, Validation: usernameValidation}
	v2 := shared.GinInputParams{Field: body.Password, Validation: passwordValidation}
	v3 := shared.GinInputParams{Field: body.Language, Validation: languageValidation}
	if shared.CheckGinInput(v1, v2, v3) {
		shared.SendGinError(c, shared.NewStatusUnprocessableEntity())
		return
	}

	user := domain.User{
		Username: body.Username,
		Password: body.Password,
	}

	tokens, err := h.UsersService.Registration(&user, &body.Language)
	if err != nil {
		shared.SendGinError(c, err)
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
	var user domain.User
	err := c.ShouldBindJSON(&user)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	v1 := shared.GinInputParams{Field: user.Username, Validation: usernameValidation}
	v2 := shared.GinInputParams{Field: user.Password, Validation: passwordValidation}
	if shared.CheckGinInput(v1, v2) {
		shared.SendGinError(c, shared.NewStatusUnprocessableEntity())
		return
	}

	tokens, err := h.UsersService.Login(&user)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	// The default 200 status is sent
	c.JSON(http.StatusOK, tokens)
}

/** input:
 * {}
 */
func (h *Handler) Logout(c *gin.Context) {
	au, err := shared.ExtractTokenMetadata(c.Request)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewAuthorization("Something went wrong when reading token"))
		return
	}

	err = h.UsersService.Logout(au)
	if err != nil {
		shared.SendGinError(c, err)
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
	var input domain.RefreshInput
	err := c.ShouldBindJSON(&input)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}
	refreshToken := input.Refresh_token
	if refreshToken == "" {
		shared.SendGinError(c, shared.NewAuthorization("Refresh token expired"))
		return
	}

	tokens, err := h.UsersService.Refresh(&input)
	if err != nil {
		shared.SendGinError(c, err)
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
	var user domain.User
	err := c.ShouldBindJSON(&user)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	v1 := shared.GinInputParams{Field: user.Username, Validation: usernameValidation}
	if shared.CheckGinInput(v1) {
		shared.SendGinError(c, shared.NewStatusUnprocessableEntity())
		return
	}

	err = h.UsersService.ResetPassword(&user)
	if err != nil {
		shared.SendGinError(c, err)
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
	var user domain.User
	err := c.ShouldBindJSON(&user)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	v1 := shared.GinInputParams{Field: user.Username, Validation: usernameValidation}
	if shared.CheckGinInput(v1) {
		shared.SendGinError(c, shared.NewStatusUnprocessableEntity())
		return
	}

	tokens, err := h.UsersService.ConfirmResetPassword(&user)
	if err != nil {
		shared.SendGinError(c, err)
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
	var userPassword domain.UserPassword
	err := c.ShouldBindJSON(&userPassword)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	v1 := shared.GinInputParams{Field: userPassword.OldPassword, Validation: passwordValidation}
	v2 := shared.GinInputParams{Field: userPassword.NewPassword, Validation: passwordValidation}
	if shared.CheckGinInput(v1, v2) {
		shared.SendGinError(c, shared.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	tokens, err := h.UsersService.UpdatePassword(userPassword.OldPassword, userPassword.NewPassword, idUser)
	if err != nil {
		shared.SendGinError(c, err)
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
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}
	refreshToken := mapToken["refresh_token"]
	if refreshToken == "" {
		shared.SendGinError(c, shared.NewAuthorization("Refresh token expired"))
		return
	}

	challenge, err := h.UsersService.Challenge(refreshToken)
	if err != nil {
		shared.SendGinError(c, err)
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
	var user domain.User

	err := c.ShouldBindJSON(&user)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	user.ID = idUser

	res, err := h.UsersService.SecureAuth(&user)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, *res)
}

// Handler wires the auth/user HTTP endpoints to their service.
type Handler struct {
	UsersService domain.UsersService
}
