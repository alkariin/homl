package web

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func healthz(t *testing.T, h *HealthHandler) (int, map[string]string) {
	t.Helper()
	r := gin.New()
	r.GET("/healthz", h.Healthz)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))

	var body map[string]string
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &body))
	return rec.Code, body
}

var ok = func(context.Context) error { return nil }

// The build identity travels with the component states so whoever polls
// /healthz — an operator, the app's About screen — knows which build answers.
func TestHealthzReportsTheVersion(t *testing.T) {
	code, body := healthz(t, &HealthHandler{CheckDB: ok, CheckRedis: ok, Version: "v0.1.0"})

	assert.Equal(t, http.StatusOK, code)
	assert.Equal(t, map[string]string{"mysql": "ok", "redis": "ok", "version": "v0.1.0"}, body)
}

// A failing dependency flips the status but keeps the version: the build that
// is unhealthy is exactly the information one wants then.
func TestHealthzKeepsTheVersionWhenUnhealthy(t *testing.T) {
	down := func(context.Context) error { return errors.New("down") }
	code, body := healthz(t, &HealthHandler{CheckDB: ok, CheckRedis: down, Version: "v0.1.0"})

	assert.Equal(t, http.StatusServiceUnavailable, code)
	assert.Equal(t, "unavailable", body["redis"])
	assert.Equal(t, "v0.1.0", body["version"])
}
