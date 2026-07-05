package web

import (
	"net/http"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/gin-gonic/gin"
)

// ctxUserIDKey is the gin context key under which the authenticated user id is
// stored by TokenAuthMiddleware.
const ctxUserIDKey = "userID"

// TokenAuthMiddleware is the single authentication checkpoint: it resolves the
// request's identity through the Authenticator, which both verifies the access
// token and checks the session in the auth store. A revoked session (e.g. after
// logout) is therefore rejected here, before any handler runs. The resolved
// user id is stashed in the context for handlers to read via UserIDFromContext.
func TokenAuthMiddleware(auth Authenticator) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, err := auth.GetUserIdFromToken(c.Request)
		if err != nil {
			c.JSON(http.StatusUnauthorized, "Invalid JWT")
			c.Abort()
			return
		}
		c.Set(ctxUserIDKey, userID)
		c.Next()
	}
}

// UserIDFromContext returns the authenticated user id set by
// TokenAuthMiddleware. It errors if the middleware did not run.
func UserIDFromContext(c *gin.Context) (uint64, error) {
	v, ok := c.Get(ctxUserIDKey)
	if !ok {
		return 0, apperror.NewAuthorization("Not authorized")
	}
	userID, ok := v.(uint64)
	if !ok {
		return 0, apperror.NewAuthorization("Not authorized")
	}
	return userID, nil
}
