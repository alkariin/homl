package web

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// CorsMiddleware sets CORS headers on every response and short-circuits OPTIONS preflight
// requests. An empty allowed origin falls back to "*".
func CorsMiddleware(origin string) gin.HandlerFunc {
	if origin == "" {
		origin = "*"
	}
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", origin)
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		// If-None-Match and ETag: the conditional reads (see ETag), which a
		// browser client must be allowed to send and to read. X-Homl-Client:
		// what the app calls itself (see ClientInfo).
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization, If-None-Match, X-Homl-Client")
		c.Header("Access-Control-Expose-Headers", "ETag")
		c.Header("Access-Control-Max-Age", "86400")
		// The response depends on the Origin header: caches must not serve it
		// to a different origin.
		c.Header("Vary", "Origin")
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

// SecurityHeaders sets defensive response headers on every response. The API
// serves JSON only, so framing and content-type sniffing are never legitimate.
func SecurityHeaders() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("Referrer-Policy", "no-referrer")
		c.Next()
	}
}
