package controller

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/homl/homl-web/helper"
	"github.com/alkariin/homl/homl-web/model"
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
func (h *Handler) GetCategories(c *gin.Context) {
	userId, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	res, err := h.CategoriesService.GetCategories(userId)
	if err != nil {
		helper.SendGinError(c, err)
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
func (h *Handler) CreateCategory(c *gin.Context) {
	var category *model.Category
	err := c.ShouldBindJSON(&category)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}

	v1 := helper.GinInputParams{Field: category.Category, Validation: categoryValidation}
	v2 := helper.GinInputParams{Field: category.Color, Validation: colorValidation}
	if helper.CheckGinInput(v1, v2) {
		helper.SendGinError(c, helper.NewStatusUnprocessableEntity())
		return
	}

	category.IdUser, err = h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	err = h.CategoriesService.CreateCategory(category)
	if err != nil {
		helper.SendGinError(c, err)
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
func (h *Handler) UpdateCategory(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		helper.SendGinError(c, helper.NewStatusUnprocessableEntity())
		return
	}

	var category model.Category
	err = c.ShouldBindJSON(&category)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}
	category.Id = uint(idParam)

	v1 := helper.GinInputParams{Field: category.Category, Validation: categoryValidation}
	v2 := helper.GinInputParams{Field: category.Color, Validation: colorValidation}
	if helper.CheckGinInput(v1, v2) {
		helper.SendGinError(c, helper.NewInternal())
		return
	}

	err = h.CategoriesService.UpdateCategory(&category)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/** input:
 * id: uint
 * {
 *   moveTags: bool
 * }
 */
func (h *Handler) DeleteCategory(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}
	idCategory := uint(idParam)

	type bodyRequest struct {
		MoveTags bool `json:"moveTags"`
	}

	var body bodyRequest
	err = c.ShouldBindJSON(&body)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}

	err = helper.CheckGinInputStruct(body)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	err = h.CategoriesService.DeleteCategory(idCategory, idUser, body.MoveTags)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}
