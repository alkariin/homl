package apperror

import (
	"encoding/json"
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

func TestStatusFallsBackToInternal(t *testing.T) {
	assert.Equal(t, http.StatusInternalServerError, Status(errors.New("not an app error")))
}

// The second-factor refusal is the contract a client builds its prompt on: a
// 401 carrying a code and the factor to ask for, while the message stays the
// one shipped clients still match on.
func TestSecondFactorRequired(t *testing.T) {
	cases := []struct {
		factor  string
		message string
	}{
		{FactorPin, "Pin must be provided"},
		{FactorFingerprint, "Signature must be provided"},
	}

	for _, c := range cases {
		t.Run(c.factor, func(t *testing.T) {
			err := NewSecondFactorRequired(c.factor)

			assert.Equal(t, http.StatusUnauthorized, Status(err))
			out, jsonErr := json.Marshal(err)
			assert.NoError(t, jsonErr)
			assert.JSONEq(t,
				`{"type":"AUTHORIZATION","message":"`+c.message+`","code":"SECOND_FACTOR_REQUIRED","factor":"`+c.factor+`"}`,
				string(out))
		})
	}

	t.Run("no other error carries a factor", func(t *testing.T) {
		out, err := json.Marshal(NewPinLocked())
		assert.NoError(t, err)
		assert.NotContains(t, string(out), "factor")
	})
}
