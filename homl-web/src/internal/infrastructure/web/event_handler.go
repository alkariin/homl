package web

import (
	"net/http"
	"strconv"
	"time"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
	"github.com/gin-gonic/gin"
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
 * query:
 *   ?tags=<name>&tags=<name> (optional filter, repeat the param per tag)
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
func (h *EventHandler) GetEvents(c *gin.Context) {
	tags := c.QueryArray("tags")

	userId, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	events, err := h.EventsService.GetEvents(userId, tags)
	if err != nil {
		SendGinError(c, err)
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
func (h *EventHandler) CreateEvent(c *gin.Context) {
	type bodyRequest struct {
		Description string    `json:"description"`
		Date        time.Time `json:"date" validate:"required"`
		TagsId      []uint    `json:"tagsId" validate:"required"`
	}

	var body *bodyRequest
	err := c.ShouldBindJSON(&body)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	err = CheckGinInputStruct(body)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	event := &event.Event{
		Description: body.Description,
		Date:        body.Date,
	}

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.EventsService.CreateEvent(idUser, event, body.TagsId)
	if err != nil {
		SendGinError(c, err)
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
func (h *EventHandler) UpdateEvent(c *gin.Context) {
	type bodyRequest struct {
		Description string    `json:"description"`
		Date        time.Time `json:"date" validate:"required"`
		TagsId      []uint    `json:"tagsId" validate:"required"`
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

	err = CheckGinInputStruct(body)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}

	event := &event.Event{
		Id:          uint(idParam),
		Description: body.Description,
		Date:        body.Date,
	}

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.EventsService.UpdateEvent(idUser, event, body.TagsId)
	if err != nil {
		SendGinError(c, err)
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/**
 * input:
 * id: uint
 * {}
 */
func (h *EventHandler) DeleteEvent(c *gin.Context) {
	idParam, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewStatusUnprocessableEntity())
		return
	}
	id := uint(idParam)

	err = h.EventsService.DeleteEvent(id)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

// Handler wires the events HTTP endpoints to their service.
type EventHandler struct {
	EventsService application.EventsService
}
