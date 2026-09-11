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

/**
 * Send only the idCategory of each tag so that it doesn't require a joining with categories table.
 * The FE knows the categories because it does the GET Categories during the initialization.
 *
 * The tags filter uses AND semantics: only events matching ALL the given tag
 * names are returned. A name matches through its whole synonym group (main
 * tag + synonyms). Browsers cannot send a GET body, so it is carried as
 * repeated query parameters (?tags=<name>&tags=<name>).
 *
 * response:
 * [
 *   {
 *     id: uint,
 *     description: string,
 *     date: string,
 *     endDate: string | null,
 *     isOngoing: bool,
 *     tags: [
 *       {
 *         id: uint,
 *         tag: string,
 *         idCategory: uint,
 *         idParentTag: uint | null
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

	events, err := h.EventsService.GetEvents(c.Request.Context(), userId, tags)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.JSON(http.StatusOK, events)
}

/**
 * The tag of the date are set by the BE (from the period) to avoid the FE to curl a request without dates.
 * It is allowed to create an event with an empty tagsId array (the BE will just add the date tags).
 *
 * An event is a single day (no endDate, isOngoing false), a closed period
 * (endDate on or after date, inclusive) or an open period (isOngoing true, no
 * endDate). Any other combination is a 400 (see application.validatePeriod).
 *
 * input:
 * {
 *   description?: string,
 *   date: time,
 *   endDate?: time | null,
 *   isOngoing?: bool,
 *   tagsId: []uint
 * }
 */
func (h *EventHandler) CreateEvent(c *gin.Context) {
	type bodyRequest struct {
		Description string     `json:"description"`
		Date        time.Time  `json:"date" validate:"required"`
		EndDate     *time.Time `json:"endDate"`
		IsOngoing   bool       `json:"isOngoing"`
		TagsId      []uint     `json:"tagsId" validate:"required"`
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
		EndDate:     body.EndDate,
		IsOngoing:   body.IsOngoing,
	}

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.EventsService.CreateEvent(c.Request.Context(), idUser, event, body.TagsId)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusCreated)
}

/**
 * Full-state update: an omitted endDate clears it and an omitted isOngoing
 * resets it, exactly like the description. Closing an open period is a PATCH
 * with endDate set and isOngoing false.
 *
 * input:
 * id: uint
 * {
 *   description?: string,
 *   date: time,
 *   endDate?: time | null,
 *   isOngoing?: bool,
 *   tagsId: []uint
 * }
 */
func (h *EventHandler) UpdateEvent(c *gin.Context) {
	type bodyRequest struct {
		Description string     `json:"description"`
		Date        time.Time  `json:"date" validate:"required"`
		EndDate     *time.Time `json:"endDate"`
		IsOngoing   bool       `json:"isOngoing"`
		TagsId      []uint     `json:"tagsId" validate:"required"`
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
		EndDate:     body.EndDate,
		IsOngoing:   body.IsOngoing,
	}

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.EventsService.UpdateEvent(c.Request.Context(), idUser, event, body.TagsId)
	if err != nil {
		SendGinError(c, err)
		return
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

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.EventsService.DeleteEvent(c.Request.Context(), id, idUser)
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
