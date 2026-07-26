package web

import (
	"context"
	"net/http"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/e2ee"
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

// E2EEFlagSource exposes the persisted per-user E2EE flag to the middleware
// below. Implemented by persistence.E2EERepository.
type E2EEFlagSource interface {
	IsEnabled(ctx context.Context, idUser uint64) (bool, error)
}

// E2EEFlagMiddleware loads the authenticated user's E2EE flag once per
// request and stores it in the request context, where the application and
// persistence layers branch on it (encrypt/decrypt vs pass-through, tag
// search column, date-tag management). Must run after TokenAuthMiddleware.
func E2EEFlagMiddleware(src E2EEFlagSource) gin.HandlerFunc {
	return func(c *gin.Context) {
		idUser, err := UserIDFromContext(c)
		if err != nil {
			SendGinError(c, err)
			c.Abort()
			return
		}

		enabled, err := src.IsEnabled(c.Request.Context(), idUser)
		if err != nil {
			SendGinError(c, apperror.NewInternal())
			c.Abort()
			return
		}

		c.Request = c.Request.WithContext(e2ee.WithEnabled(c.Request.Context(), enabled))
		c.Next()
	}
}
