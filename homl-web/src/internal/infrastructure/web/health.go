package web

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// healthCheckTimeout bounds each dependency probe so a hung backend cannot
// stall the health endpoint (and whatever orchestrator polls it).
const healthCheckTimeout = 2 * time.Second

// HealthHandler answers GET /healthz by pinging the service's dependencies.
// The checks are injected as plain functions so this package does not depend
// on the sql/redis drivers.
type HealthHandler struct {
	CheckDB    func(ctx context.Context) error
	CheckRedis func(ctx context.Context) error
	// Version is reported alongside the component states so an operator (or
	// the app's About screen) can tell which build answers.
	Version string
}

func (h *HealthHandler) Healthz(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), healthCheckTimeout)
	defer cancel()

	status := http.StatusOK
	components := gin.H{"mysql": "ok", "redis": "ok", "version": h.Version}

	if err := h.CheckDB(ctx); err != nil {
		status = http.StatusServiceUnavailable
		components["mysql"] = "unavailable"
	}
	if err := h.CheckRedis(ctx); err != nil {
		status = http.StatusServiceUnavailable
		components["redis"] = "unavailable"
	}

	c.JSON(status, components)
}
