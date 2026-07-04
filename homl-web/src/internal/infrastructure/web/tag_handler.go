package web

import (
	"net/http"
	"strconv"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/gin-gonic/gin"
)

var tagValidation = "required"
var idCategoryValidation = "required"

/** input:
 * {
 *   tag: string,
 *   idCategory: uint
 * }
 */
func (h *TagHandler) CreateTag(c *gin.Context) {
	var tag *category.Tag
	err := c.ShouldBindJSON(&tag)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	v1 := GinInputParams{Field: tag.Tag, Validation: tagValidation}
	v2 := GinInputParams{Field: tag.IdCategory, Validation: idCategoryValidation}
	if CheckGinInput(v1, v2) {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := h.Auth.GetUserIdFromToken(c.Request)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.TagsService.CreateTag(idUser, tag)
	if err != nil {
		SendGinError(c, err)
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
func (h *TagHandler) UpdateTag(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	var tag *category.Tag
	err = c.ShouldBindJSON(&tag)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}
	tag.Id = uint(idParam)

	v1 := GinInputParams{Field: tag.Tag, Validation: tagValidation}
	v2 := GinInputParams{Field: tag.IdCategory, Validation: idCategoryValidation}
	if CheckGinInput(v1, v2) {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := h.Auth.GetUserIdFromToken(c.Request)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.TagsService.UpdateTag(idUser, tag)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/** input:
 * id: uint
 * {}
 */
func (h *TagHandler) DeleteTag(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}
	id := uint(idParam)

	idUser, err := h.Auth.GetUserIdFromToken(c.Request)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.TagsService.DeleteTag(id, idUser)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

// Handler wires the tags HTTP endpoints to their service.
type TagHandler struct {
	TagsService application.TagsService
	Auth        Authenticator
}
