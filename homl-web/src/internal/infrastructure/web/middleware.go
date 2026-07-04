package web

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// TokenAuthMiddleware rejects requests that do not carry a valid access token.
func TokenAuthMiddleware(tokens TokenParser) gin.HandlerFunc {
	return func(c *gin.Context) {
		err := tokens.Valid(c.Request)
		if err != nil {
			c.JSON(http.StatusUnauthorized, "Invalid JWT")
			c.Abort()
			return
		}
		c.Next()
	}
}
