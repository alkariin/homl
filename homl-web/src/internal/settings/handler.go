package settings

import (
	"net/http"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/shared"
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
func (h *Handler) GetSettings(c *gin.Context) {
	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	settings, err := h.SettingsService.GetSettings(idUser)
	if err != nil {
		shared.SendGinError(c, err)
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
func (h *Handler) UpdateSettings(c *gin.Context) {
	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	var settings domain.Settings
	err = c.ShouldBindJSON(&settings)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	err = shared.CheckGinInputStruct(settings)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	newSettings, err := h.SettingsService.UpdateSettings(idUser, &settings)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, newSettings)
}

// Handler wires the settings HTTP endpoints to their service.
type Handler struct {
	SettingsService domain.SettingsService
	UsersService    domain.Authenticator
}
