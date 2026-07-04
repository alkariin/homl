package web

import (
	"net/http"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
)

// TokenParser validates access tokens on incoming requests and extracts their
// metadata. Implemented by infrastructure/auth.JWT.
type TokenParser interface {
	Valid(r *http.Request) error
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
