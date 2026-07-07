package web

import (
	"net/http"
	"strconv"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/person"
	"github.com/gin-gonic/gin"
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
func (h *PersonHandler) GetPersons(c *gin.Context) {
	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	response, err := h.PersonsService.GetPersons(c.Request.Context(), idUser)
	if err != nil {
		SendGinError(c, err)
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
func (h *PersonHandler) CreatePerson(c *gin.Context) {
	type bodyRequest struct {
		person.Person
		Nicknames []string `json:"nicknames"`
	}

	var body *bodyRequest
	err := c.ShouldBindJSON(&body)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	v1 := GinInputParams{Field: body.Firstname, Validation: firstnameValidation}
	v2 := GinInputParams{Field: body.Lastname, Validation: lastnameValidation}
	if CheckGinInput(v1, v2) {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.PersonsService.CreatePerson(c.Request.Context(), &body.Person, body.Nicknames, idUser)
	if err != nil {
		SendGinError(c, err)
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
func (h *PersonHandler) UpdatePerson(c *gin.Context) {
	type bodyRequest struct {
		person.Person
		Nicknames []person.Nickname `json:"nicknames"`
	}

	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	var body *bodyRequest
	err = c.ShouldBindJSON(&body)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}
	body.Id = uint(idParam)

	v1 := GinInputParams{Field: body.Firstname, Validation: firstnameValidation}
	v2 := GinInputParams{Field: body.Lastname, Validation: lastnameValidation}
	if CheckGinInput(v1, v2) {
		SendGinError(c, apperror.NewStatusUnprocessableEntity())
		return
	}

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.PersonsService.UpdatePerson(c.Request.Context(), &body.Person, body.Nicknames, idUser)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/** input:
 *	 id: uint
 * {}
 */
func (h *PersonHandler) DeletePerson(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}
	idPerson := uint(idParam)

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.PersonsService.DeletePerson(c.Request.Context(), idPerson, idUser)
	if err != nil {
		SendGinError(c, err)
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

// Handler wires the persons HTTP endpoints to their service.
type PersonHandler struct {
	PersonsService application.PersonsService
}
