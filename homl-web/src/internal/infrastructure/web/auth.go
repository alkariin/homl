package web

import (
	"net/http"
	"strings"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
)

// bearerToken returns the raw token from an "Authorization: Bearer <token>"
// header, or "" when absent/malformed. Used for opaque tokens (e.g. password
// reset) that are not parsed as JWTs.
func bearerToken(r *http.Request) string {
	parts := strings.SplitN(r.Header.Get("Authorization"), " ", 2)
	if len(parts) == 2 && strings.EqualFold(parts[0], "Bearer") {
		return strings.TrimSpace(parts[1])
	}
	return ""
}

// TokenParser reads access tokens off incoming requests and extracts their
// metadata. Implemented by infrastructure/auth.JWT.
type TokenParser interface {
	ExtractAccessDetails(r *http.Request) (*user.AccessDetails, error)
}

// SessionStore resolves an access token's metadata to the authenticated user
// id. Implemented by the users repository (Redis auth store).
type SessionStore interface {
	FetchAuth(authD *user.AccessDetails) (uint64, error)
}

// Authenticator resolves the authenticated user id from an incoming request.
// It is consumed by every handler that needs the current user's identity.
type Authenticator interface {
	GetUserIdFromToken(request *http.Request) (uint64, error)
}

// TokenAuthenticator implements Authenticator: it parses the access token off
// the request and resolves the session in the auth store.
type TokenAuthenticator struct {
	Tokens   TokenParser
	Sessions SessionStore
}

func (a *TokenAuthenticator) GetUserIdFromToken(request *http.Request) (uint64, error) {
	accessDetails, err := a.Tokens.ExtractAccessDetails(request)
	if err != nil {
		return 0, apperror.NewAuthorization("Not authorized")
	}
	userId, err := a.Sessions.FetchAuth(accessDetails)
	if err != nil {
		return 0, apperror.NewAuthorization("Not authorized")
	}
	return userId, nil
}
