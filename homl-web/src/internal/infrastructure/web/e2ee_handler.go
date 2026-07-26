package web

import (
	"net/http"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/e2ee"
	"github.com/gin-gonic/gin"
)

/**
 * Atomic whole-dataset migration flipping the user's E2EE mode (docs/e2ee.md).
 * The id sets must exactly match the user's stored rows; any drift answers 409
 * and the client refetches and retries. On enable the values are client
 * blobs and keyCheck is required; on disable they are plaintext.
 *
 * input:
 * {
 *   direction: "enable" | "disable",
 *   keyCheck?: string,  // enable only: hex HMAC-SHA256 verifying a recovery phrase later
 *   categories: [{ id: uint, category: string }],
 *   tags:       [{ id: uint, tag: string, tagIndex?: string }],
 *   events:     [{ id: uint, description: string }]
 * }
 */
func (h *E2EEHandler) Migrate(c *gin.Context) {
	type bodyRequest struct {
		Direction  string                   `json:"direction" validate:"required"`
		KeyCheck   string                   `json:"keyCheck"`
		Categories []e2ee.MigrationCategory `json:"categories"`
		Tags       []e2ee.MigrationTag      `json:"tags"`
		Events     []e2ee.MigrationEvent    `json:"events"`
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

	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	data := &e2ee.MigrationData{
		Categories: body.Categories,
		Tags:       body.Tags,
		Events:     body.Events,
	}

	err = h.E2EEService.Migrate(c.Request.Context(), idUser, body.Direction, body.KeyCheck, data)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

/**
 * Lost-key escape hatch: deletes every event, tag and category of the user,
 * reseeds the default categories and disables E2EE. Destructive and
 * irreversible; the client double-confirms before calling.
 *
 * input: {}
 */
func (h *E2EEHandler) Purge(c *gin.Context) {
	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}

	err = h.E2EEService.Purge(c.Request.Context(), idUser)
	if err != nil {
		SendGinError(c, err)
		return
	}

	c.Writer.WriteHeader(http.StatusNoContent)
}

// Handler wires the E2EE HTTP endpoints to their service.
type E2EEHandler struct {
	E2EEService application.E2EEService
}
