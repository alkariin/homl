package web

import (
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

// CorsMiddleware sets CORS headers on every response and short-circuits OPTIONS preflight
// requests. Allowed origin defaults to "*"; set CORS_ORIGIN to restrict it.
func CorsMiddleware() gin.HandlerFunc {
	origin := os.Getenv("CORS_ORIGIN")
	if origin == "" {
		origin = "*"
	}
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", origin)
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization")
		c.Header("Access-Control-Max-Age", "86400")
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}
