package web

import (
	"net/http"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/gin-gonic/gin"
)

/** response:
 * {
 *   language: string,
 *   defaultScreen: bool,
 *   isFingerprintEnabled: bool,
 *   isPinEnabled: bool
 * }
 */
func (h *SettingsHandler) GetSettings(c *gin.Context) {
	idUser, err := h.Auth.GetUserIdFromToken(c.Request)
	if err != nil {
		SendGinError(c, err)
		return
	}

	settings, err := h.SettingsService.GetSettings(c.Request.Context(), idUser)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, *settings)
}

/** input:
 * {
 *	 language: string,
 *   defaultScreen: bool,
 *   isFingerprintEnabled: bool,
 *   isPinEnabled: bool,
 *   pin?: string,
 *   pkey?: string
 * }
 */
func (h *SettingsHandler) UpdateSettings(c *gin.Context) {
	idUser, err := h.Auth.GetUserIdFromToken(c.Request)
	if err != nil {
		SendGinError(c, err)
		return
	}

	var settings user.Settings
	err = c.ShouldBindJSON(&settings)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	err = CheckGinInputStruct(settings)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	newSettings, err := h.SettingsService.UpdateSettings(c.Request.Context(), idUser, &settings)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, newSettings)
}

// Handler wires the settings HTTP endpoints to their service.
type SettingsHandler struct {
	SettingsService application.SettingsService
	Auth            Authenticator
}
