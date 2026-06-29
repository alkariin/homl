package controller

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/homl/homl-web/helper"
	"github.com/alkariin/homl/homl-web/model"
)

var firstnameValidation = "required"
var lastnameValidation = "required"
var nicknamesValidation = "required"

/**
 * response:
 *  {
 *	  id: uint,
 *	  firstname: string,
 *    lastname: string,
 *    nicknames: [
 *	    {
 *        id: uint,
 *        nickname: string
 *      }
 *    ]
 *  }
 */
func (h *Handler) GetPersons(c *gin.Context) {
	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	response, err := h.PersonsService.GetPersons(idUser)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, response)
}

/** input:
 * {
 *   firstname: string,
 *   lastname: string,
 *   nicknames?: string[]
 * }
 */
func (h *Handler) CreatePerson(c *gin.Context) {
	type bodyRequest struct {
		model.Person
		Nicknames []string `json:"nicknames"`
	}

	var body *bodyRequest
	err := c.ShouldBindJSON(&body)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}

	v1 := helper.GinInputParams{Field: body.Firstname, Validation: firstnameValidation}
	v2 := helper.GinInputParams{Field: body.Lastname, Validation: lastnameValidation}
	if helper.CheckGinInput(v1, v2) {
		helper.SendGinError(c, helper.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	err = h.PersonsService.CreatePerson(&body.Person, body.Nicknames, idUser)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusCreated)
}

/**
 * If the nickname exist the id should be provided.
 *
 * input:
 * id: uint
 * {
 *   firstname: string,
 *   lastname: string,
 *   nicknames?: [
 *	   {
 *       id?: uint,
 *       nickname: string
 *     }
 *   ]
 * }
 */
func (h *Handler) UpdatePerson(c *gin.Context) {
	type bodyRequest struct {
		model.Person
		Nicknames []model.Nickname `json:"nicknames"`
	}

	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}

	var body *bodyRequest
	err = c.ShouldBindJSON(&body)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}
	body.Id = uint(idParam)

	v1 := helper.GinInputParams{Field: body.Firstname, Validation: firstnameValidation}
	v2 := helper.GinInputParams{Field: body.Lastname, Validation: lastnameValidation}
	if helper.CheckGinInput(v1, v2) {
		helper.SendGinError(c, helper.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	err = h.PersonsService.UpdatePerson(&body.Person, body.Nicknames, idUser)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/** input:
 *	 id: uint
 * {}
 */
func (h *Handler) DeletePerson(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		helper.SendGinMyCustomError(c, err, helper.NewStatusUnprocessableEntity())
		return
	}
	idPerson := uint(idParam)

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		helper.SendGinError(c, err)
		return
	}

	err = h.PersonsService.DeletePerson(idPerson, idUser)
	if err != nil {
		helper.SendGinError(c, err)
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}
