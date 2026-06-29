package controller

import (
	"net/http"

	"github.com/alkariin/homl/homl-web/helper"
	"github.com/alkariin/homl/homl-web/model"
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
		helper.SendGinError(c, err)
		return
	}

	settings, err := h.SettingsService.GetSettings(idUser)
	if err != nil {
		helper.SendGinError(c, err)
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
		helper.SendGinError(c, err)
		return
	}

	var settings model.Settings
	err = c.ShouldBindJSON(&settings)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}

	err = helper.CheckGinInputStruct(settings)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}

	newSettings, err := h.SettingsService.UpdateSettings(idUser, &settings)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, newSettings)
}
