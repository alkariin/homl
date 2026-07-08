package web

import (
	"context"
	"time"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/gin-gonic/gin"
)

// RateLimiter is the port for per-key request throttling. Implemented by
// infrastructure/ratelimit (Redis-backed).
type RateLimiter interface {
	// Allow records a hit for key and reports whether it stays within limit for
	// the given window.
	Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, error)
}

// RateLimit throttles a route per client IP. name namespaces the counter so
// different endpoints don't share a budget. It fails open (allows the request)
// if the limiter backend errors, to avoid locking users out on a Redis blip.
func RateLimit(rl RateLimiter, name string, limit int, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		key := "rl:" + name + ":" + c.ClientIP()
		allowed, err := rl.Allow(c.Request.Context(), key, limit, window)
		if err == nil && !allowed {
			SendGinError(c, apperror.NewTooManyRequests())
			c.Abort()
			return
		}
		c.Next()
	}
}
