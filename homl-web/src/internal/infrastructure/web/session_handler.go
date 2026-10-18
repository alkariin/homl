package web

import (
	"net/http"
	"strings"
	"unicode"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/gin-gonic/gin"
)

// clientHeader is how the app says what it is, e.g. "android 0.5.0": it
// names the device session the request opens or renews.
const clientHeader = "X-Homl-Client"

// maxClientLength bounds what is kept of clientHeader: a label, not a store.
const maxClientLength = 64

// ClientInfo carries what a request says about its client — the
// clientHeader label and the address it came from — in the request context,
// for the device session a login or a refresh records
// (docs/auth-flows.md, "Signed-in devices").
func ClientInfo() gin.HandlerFunc {
	return func(c *gin.Context) {
		info := user.SessionInfo{
			Client: clientLabel(c.GetHeader(clientHeader)),
			IP:     c.ClientIP(),
		}
		c.Request = c.Request.WithContext(user.WithSessionInfo(c.Request.Context(), info))
		c.Next()
	}
}

// clientLabel keeps the printable part of a client header, trimmed and
// bounded: it is shown back to the user, never interpreted.
func clientLabel(raw string) string {
	label := strings.Map(func(r rune) rune {
		if unicode.IsPrint(r) {
			return r
		}
		return -1
	}, strings.TrimSpace(raw))
	if runes := []rune(label); len(runes) > maxClientLength {
		label = string(runes[:maxClientLength])
	}
	return label
}

/** output:
 * [ { id, client, ip, createdAt: time | null, lastSeenAt: time, current } ]
 */
func (h *UserHandler) ListSessions(c *gin.Context) {
	au, err := h.Tokens.ExtractAccessDetails(c.Request)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewAuthorization("Not authorized"))
		return
	}
	sessions, err := h.UsersService.ListSessions(c.Request.Context(), au)
	if err != nil {
		SendGinError(c, err)
		return
	}
	c.JSON(http.StatusOK, sessions)
}

// RevokeSession signs one device out: its next request is refused, and its
// refresh too. 404 for an id the user has no session under.
func (h *UserHandler) RevokeSession(c *gin.Context) {
	idUser, err := UserIDFromContext(c)
	if err != nil {
		SendGinError(c, err)
		return
	}
	if err := h.UsersService.RevokeSession(c.Request.Context(), idUser, c.Param("id")); err != nil {
		SendGinError(c, err)
		return
	}
	c.Writer.WriteHeader(http.StatusNoContent)
}

// RevokeOtherSessions signs out every device but the one asking.
func (h *UserHandler) RevokeOtherSessions(c *gin.Context) {
	au, err := h.Tokens.ExtractAccessDetails(c.Request)
	if err != nil {
		SendGinMyCustomError(c, err, apperror.NewAuthorization("Not authorized"))
		return
	}
	if err := h.UsersService.RevokeOtherSessions(c.Request.Context(), au); err != nil {
		SendGinError(c, err)
		return
	}
	c.Writer.WriteHeader(http.StatusNoContent)
}
