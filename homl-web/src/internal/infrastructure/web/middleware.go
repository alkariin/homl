package web

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/homl/homl-web/internal/token"
)

// Authenticator resolves the authenticated user id from an incoming request.
// It is implemented by the users service and consumed by every handler that
// needs the current user's identity.
type Authenticator interface {
	GetUserIdFromToken(request *http.Request) (uint64, error)
}

// TokenAuthMiddleware rejects requests that do not carry a valid access token.
func TokenAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		err := token.Valid(c.Request)
		if err != nil {
			c.JSON(http.StatusUnauthorized, "Invalid JWT")
			c.Abort()
			return
		}
		c.Next()
	}
}
