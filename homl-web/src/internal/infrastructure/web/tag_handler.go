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
 *   idCategory: uint,
 *   idParentTag?: uint  // makes the new tag a synonym of an existing main tag
 *                       // of the same category (one level of depth only)
 * }
 * output:
 * { id: uint }
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

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	idTag, err := h.TagsService.CreateTag(c.Request.Context(), idUser, tag)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.JSON(http.StatusCreated, gin.H{"id": idTag})
}

/** input:
 * id: uint
 * {
 *   tag: string,
 *   idCategory: uint,
 *   idParentTag?: uint  // full-state semantics: omitted or null detaches the
 *                       // tag from its parent (it becomes a main tag again)
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

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.TagsService.UpdateTag(c.Request.Context(), idUser, tag)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/** input:
 * id: uint
 * {}
 *
 * Deleting a synonym repoints its tagged events to the parent tag; deleting a
 * main tag promotes its oldest synonym as the new main tag.
 */
func (h *TagHandler) DeleteTag(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}
	id := uint(idParam)

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.TagsService.DeleteTag(c.Request.Context(), id, idUser)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

// Handler wires the tags HTTP endpoints to their service.
type TagHandler struct {
	TagsService application.TagsService
}
