package web

import (
	"net/http"
	"strconv"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/gin-gonic/gin"
)

var tagGroupNameValidation = "required"

/** input:
 * {
 *   name: string,
 *   idCategory: uint,
 *   members: uint[],     // main tags of that category, at least one
 *   nameIndex?: string   // E2EE users only (blind index of the name)
 * }
 * output:
 * { id: uint }
 */
func (h *TagGroupHandler) CreateTagGroup(c *gin.Context) {
	var group *category.TagGroup
	err := c.ShouldBindJSON(&group)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	v1 := GinInputParams{Field: group.Name, Validation: tagGroupNameValidation}
	v2 := GinInputParams{Field: group.IdCategory, Validation: idCategoryValidation}
	if CheckGinInput(v1, v2) {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	idGroup, err := h.TagGroupsService.CreateTagGroup(c.Request.Context(), idUser, group)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.JSON(http.StatusCreated, gin.H{"id": idGroup})
}

/** input:
 * id: uint
 * {
 *   name: string,
 *   members: uint[],     // full-state: replaces the stored members
 *   nameIndex?: string
 * }
 *
 * A group never changes category: an idCategory in the body is ignored.
 */
func (h *TagGroupHandler) UpdateTagGroup(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	var group *category.TagGroup
	err = c.ShouldBindJSON(&group)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}
	group.Id = uint(idParam)

	v1 := GinInputParams{Field: group.Name, Validation: tagGroupNameValidation}
	if CheckGinInput(v1) {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.TagGroupsService.UpdateTagGroup(c.Request.Context(), idUser, group)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/** input:
 * id: uint
 *
 * Deletes the group only: its tags and their events are untouched.
 */
func (h *TagGroupHandler) DeleteTagGroup(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.TagGroupsService.DeleteTagGroup(c.Request.Context(), uint(idParam), idUser)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

// TagGroupHandler wires the tag group HTTP endpoints to their service.
type TagGroupHandler struct {
	TagGroupsService application.TagGroupsService
}
