package event

import (
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/shared"
)

type Event struct {
	Id          uint      `json:"id"`
	Description string    `json:"description"`
	Date        time.Time `json:"date"` // type date doesn't exist in go
}

/**
 * Send only the idCategory of each tag so that it doesn't require a joining with categories table.
 * The FE knows the categories because it does the GET Categories during the initialization.
 *
 * input:
 * {
 *   tags?: []string
 * }
 *
 * response:
 * [
 *   {
 *     id: uint,
 *     description: string,
 *     date: string,
 *     tags: [
 *       {
 *         id: uint,
 *         tag: string,
 *         idCategory: uint
 *       }
 *     ]
 *   }
 * ]
 */
func (h *Handler) GetEvents(c *gin.Context) {
	type bodyRequest struct {
		Tags []string `json:"tags"`
	}
	var body bodyRequest

	err := c.ShouldBindJSON(&body)
	if err != nil && err != io.EOF {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	userId, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	events, err := h.EventsService.GetEvents(userId, body.Tags)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, events)
}

/**
 * The tag of the date are set by the BE (from the 'date') to avoid the FE to curl a request without dates.
 * It is allowed to create an event with an empty tagsId array (the BE will just add the date tags).
 *
 * input:
 * {
 *   description?: string,
 *   date: time,
 *   tagsId: []uint
 * }
 */
func (h *Handler) CreateEvent(c *gin.Context) {
	type bodyRequest struct {
		Description string    `json:"description"`
		Date        time.Time `json:"date" validate:"required"`
		TagsId      []uint    `json:"tagsId" validate:"required"`
	}

	var body *bodyRequest
	err := c.ShouldBindJSON(&body)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	err = shared.CheckGinInputStruct(body)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	event := &domain.Event{
		Description: body.Description,
		Date:        body.Date,
	}

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	err = h.EventsService.CreateEvent(idUser, event, body.TagsId)
	if err != nil {
		shared.SendGinError(c, err)
	}

	c.Writer.WriteHeader(http.StatusCreated)
}

/**
 * input:
 * id: uint
 * {
 *   description?: string,
 *   date: time,
 *   tagsId: []uint
 * }
 */
func (h *Handler) UpdateEvent(c *gin.Context) {
	type bodyRequest struct {
		Description string    `json:"description"`
		Date        time.Time `json:"date" validate:"required"`
		TagsId      []uint    `json:"tagsId" validate:"required"`
	}

	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	var body *bodyRequest
	err = c.ShouldBindJSON(&body)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	err = shared.CheckGinInputStruct(body)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}

	event := &domain.Event{
		Id:          uint(idParam),
		Description: body.Description,
		Date:        body.Date,
	}

	idUser, err := h.UsersService.GetUserIdFromToken(c.Request)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	err = h.EventsService.UpdateEvent(idUser, event, body.TagsId)
	if err != nil {
		shared.SendGinError(c, err)
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/**
 * input:
 * id: uint
 * {}
 */
func (h *Handler) DeleteEvent(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		shared.SendGinMyCustomError(c, err, shared.NewStatusUnprocessableEntity())
		return
	}
	id := uint(idParam)

	err = h.EventsService.DeleteEvent(id)
	if err != nil {
		shared.SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

// Handler wires the events HTTP endpoints to their service.
type Handler struct {
	EventsService domain.EventsService
	UsersService  domain.Authenticator
}
