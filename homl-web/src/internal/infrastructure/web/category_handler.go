package web

import (
	"net/http"
	"strconv"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/gin-gonic/gin"
)

var categoryValidation = "required"
var colorValidation = "required,hexcolor"

/** response:
 * {
 *   id: number,
 *   category: string,
 *   color: string,
 *   isLocked: bool,
 *   tags?: [{
 *     id: number,
 *     tag: string
 *   }]
 * }
 */
func (h *CategoryHandler) GetCategories(c *gin.Context) {
	userId, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	res, err := h.CategoriesService.GetCategories(c.Request.Context(), userId)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, res)
}

/** input:
 * {
 *   category: string,
 *	 color: string
 * }
 */
func (h *CategoryHandler) CreateCategory(c *gin.Context) {
	var category *category.Category
	err := c.ShouldBindJSON(&category)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	v1 := GinInputParams{Field: category.Category, Validation: categoryValidation}
	v2 := GinInputParams{Field: category.Color, Validation: colorValidation}
	if CheckGinInput(v1, v2) {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	category.IdUser, err = UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.CategoriesService.CreateCategory(c.Request.Context(), category)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusCreated)
}

/** input:
 *  id: uint
 * {
 *   category: string,
 *	 color: string
 * }
 */
func (h *CategoryHandler) UpdateCategory(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	var category category.Category
	err = c.ShouldBindJSON(&category)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}
	category.Id = uint(idParam)

	v1 := GinInputParams{Field: category.Category, Validation: categoryValidation}
	v2 := GinInputParams{Field: category.Color, Validation: colorValidation}
	if CheckGinInput(v1, v2) {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	category.IdUser, err = UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.CategoriesService.UpdateCategory(c.Request.Context(), &category)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/** input:
 * id: uint
 * {
 *   moveTags: bool,       // move the tags to the Other category instead of
 *                         // deleting them (deleteEvents is then ignored)
 *   deleteEvents?: bool   // also delete the events whose only non-date tags
 *                         // lived in this category
 * }
 */
func (h *CategoryHandler) DeleteCategory(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}
	idCategory := uint(idParam)

	type bodyRequest struct {
		MoveTags     bool `json:"moveTags"`
		DeleteEvents bool `json:"deleteEvents"`
	}

	var body bodyRequest
	err = c.ShouldBindJSON(&body)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	err = CheckGinInputStruct(body)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.CategoriesService.DeleteCategory(c.Request.Context(), idCategory, idUser, body.MoveTags, body.DeleteEvents)
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
 *   tags: number,            // tags (synonyms included) in the category
 *   events: number,          // events tagged with them
 *   exclusiveEvents: number  // of those, events with no other non-date tag
 * }
 */
func (h *CategoryHandler) GetCategoryUsage(c *gin.Context) {
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

	usage, err := h.CategoriesService.GetCategoryUsage(c.Request.Context(), uint(idParam), idUser)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, usage)
}

// Handler wires the categories HTTP endpoints to their service.
type CategoryHandler struct {
	CategoriesService application.CategoriesService
}
