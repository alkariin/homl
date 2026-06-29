package controller

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/homl/homl-web/helper"
	"github.com/alkariin/homl/homl-web/model"
)

var tagValidation = "required"
var idCategoryValidation = "required"

/** input:
 * {
 *   tag: string,
 *   idCategory: uint
 * }
 */
func (h *Handler) CreateTag(c *gin.Context) {
	var tag *model.Tag
	err := c.ShouldBindJSON(&tag)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}

	v1 := helper.GinInputParams{Field: tag.Tag, Validation: tagValidation}
	v2 := helper.GinInputParams{Field: tag.IdCategory, Validation: idCategoryValidation}
	if helper.CheckGinInput(v1, v2) {
		helper.SendGinError(c, helper.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	err = h.TagsService.CreateTag(idUser, tag)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusCreated)
}

/** input:
 * id: uint
 * {
 *   tag: string,
 *   idCategory: uint
 * }
 */
func (h *Handler) UpdateTag(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		helper.SendGinError(c, helper.NewStatusUnprocessableEntity())
		return
	}

	var tag *model.Tag
	err = c.ShouldBindJSON(&tag)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}
	tag.Id = uint(idParam)

	v1 := helper.GinInputParams{Field: tag.Tag, Validation: tagValidation}
	v2 := helper.GinInputParams{Field: tag.IdCategory, Validation: idCategoryValidation}
	if helper.CheckGinInput(v1, v2) {
		helper.SendGinError(c, helper.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	err = h.TagsService.UpdateTag(idUser, tag)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/** input:
 * id: uint
 * {}
 */
func (h *Handler) DeleteTag(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		helper.SendGinError(c, helper.NewStatusUnprocessableEntity())
		return
	}
	id := uint(idParam)

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	err = h.TagsService.DeleteTag(id, idUser)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}
