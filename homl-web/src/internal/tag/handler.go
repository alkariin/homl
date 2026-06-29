package tag

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/shared"
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
	var tag *domain.Tag
	err := c.ShouldBindJSON(&tag)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	v1 := shared.GinInputParams{Field: tag.Tag, Validation: tagValidation}
	v2 := shared.GinInputParams{Field: tag.IdCategory, Validation: idCategoryValidation}
	if shared.CheckGinInput(v1, v2) {
		shared.SendGinError(c, shared.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	err = h.TagsService.CreateTag(idUser, tag)
	if err != nil {
		shared.SendGinError(c, err)
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
		shared.SendGinError(c, shared.NewStatusUnprocessableEntity())
		return
	}

	var tag *domain.Tag
	err = c.ShouldBindJSON(&tag)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}
	tag.Id = uint(idParam)

	v1 := shared.GinInputParams{Field: tag.Tag, Validation: tagValidation}
	v2 := shared.GinInputParams{Field: tag.IdCategory, Validation: idCategoryValidation}
	if shared.CheckGinInput(v1, v2) {
		shared.SendGinError(c, shared.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	err = h.TagsService.UpdateTag(idUser, tag)
	if err != nil {
		shared.SendGinError(c, err)
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
		shared.SendGinError(c, shared.NewStatusUnprocessableEntity())
		return
	}
	id := uint(idParam)

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	err = h.TagsService.DeleteTag(id, idUser)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

// Handler wires the tags HTTP endpoints to their service.
type Handler struct {
	TagsService  domain.TagsService
	UsersService domain.Authenticator
}
