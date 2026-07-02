package apperror

import (
	"errors"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestErrorStatusMapping(t *testing.T) {
	cases := []struct {
		err    *Error
		status int
	}{
		{NewAuthorization("nope"), http.StatusUnauthorized},
		{NewBadRequest("bad"), http.StatusBadRequest},
		{NewConflict("user", "x"), http.StatusConflict},
		{NewInternal(), http.StatusInternalServerError},
		{NewNotFound("user", "x"), http.StatusNotFound},
		{NewStatusUnprocessableEntity(), http.StatusUnprocessableEntity},
		{NewStatusForbidden(), http.StatusForbidden},
		{NewServiceUnavailable(), http.StatusServiceUnavailable},
	}

	for _, c := range cases {
		t.Run(string(c.err.Type), func(t *testing.T) {
			assert.Equal(t, c.status, c.err.Status())
			// The package-level Status() helper must agree.
			assert.Equal(t, c.status, Status(c.err))
		})
	}
}

func TestIsError(t *testing.T) {
	appErr := NewBadRequest("bad")
	assert.Equal(t, appErr, IsError(appErr))

	plain := errors.New("plain")
	assert.Nil(t, IsError(plain))
}

func TestStatusFallsBackToInternal(t *testing.T) {
	assert.Equal(t, http.StatusInternalServerError, Status(errors.New("not an app error")))
}
