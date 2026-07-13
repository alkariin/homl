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
 * {
 *   deleteEvents?: bool  // main tag only: also delete the events whose only
 *                        // non-date tags belong to the deleted synonym group
 * }
 *
 * Deleting a synonym repoints its tagged events to the parent tag; deleting a
 * main tag deletes its whole synonym group.
 */
func (h *TagHandler) DeleteTag(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}
	id := uint(idParam)

	type bodyRequest struct {
		DeleteEvents bool `json:"deleteEvents"`
	}

	// The body stays optional so existing clients keep working.
	var body bodyRequest
	if c.Request.ContentLength > 0 {
		if err := c.ShouldBindJSON(&body); err != nil {
			SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
			return
		}
	}

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.TagsService.DeleteTag(c.Request.Context(), id, idUser, body.DeleteEvents)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/** input:
 * id: uint
 * output:
 * {
 *   events: number,          // events tagged with the tag's synonym group
 *   exclusiveEvents: number  // of those, events with no other non-date tag
 * }
 */
func (h *TagHandler) GetTagUsage(c *gin.Context) {
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

	usage, err := h.TagsService.GetTagUsage(c.Request.Context(), uint(idParam), idUser)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, usage)
}

// Handler wires the tags HTTP endpoints to their service.
type TagHandler struct {
	TagsService application.TagsService
}
