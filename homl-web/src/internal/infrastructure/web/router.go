package web

import (
	"net/http"
	"time"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/gin-gonic/gin"
)

// maxRequestBodyBytes caps request bodies API-wide. The payloads of this API
// are small JSON documents; 1 MiB leaves plenty of headroom.
const maxRequestBodyBytes = 1 << 20

// e2eeMigrateMaxBodyBytes caps the E2EE migration endpoint, whose payload
// carries the user's whole dataset re-encrypted (a few MB for years of
// events, see docs/e2ee.md).
const e2eeMigrateMaxBodyBytes = 32 << 20

// e2eeMigrateTimeout bounds the migration handler, which rewrites every row
// of the user in one transaction and can outlive the API-wide handler
// timeout on large datasets.
const e2eeMigrateTimeout = 60 * time.Second

// MaxBodySize rejects request bodies larger than n bytes. The handlers'
// ShouldBindJSON surfaces the *http.MaxBytesError, which the responder maps
// to a 413.
func MaxBodySize(n int64) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, n)
		c.Next()
	}
}

// Server groups the per-feature HTTP handlers wired into the router, plus the
// authenticator backing the auth middleware and the rate limiter guarding the
// public auth endpoints.
type Server struct {
	Auth        Authenticator
	RateLimiter RateLimiter
	E2EEFlags   E2EEFlagSource
	Health      *HealthHandler
	User        *UserHandler
	Category    *CategoryHandler
	Tag         *TagHandler
	Event       *EventHandler
	Settings    *SettingsHandler
	E2EE        *E2EEHandler
}

func SetupRouter(s *Server, baseUrl string, timeoutDuration time.Duration, isDev bool, corsOrigin string) *gin.Engine {
	if !isDev {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()
	// Do not trust X-Forwarded-For from arbitrary peers: without this, gin
	// resolves ClientIP() from any spoofed header and the per-IP rate limits
	// on the auth endpoints can be bypassed. Set an explicit proxy CIDR here
	// if the service is ever deployed behind a reverse proxy.
	if err := router.SetTrustedProxies(nil); err != nil {
		panic(err)
	}
	router.Use(CorsMiddleware(corsOrigin))
	router.Use(SecurityHeaders())

	// Liveness/readiness probe: outside the API group, unauthenticated, not
	// rate limited (orchestrators poll it).
	if s.Health != nil {
		router.GET("/healthz", s.Health.Healthz)
	}

	g := router.Group(baseUrl)
	g.Use(MaxBodySize(maxRequestBodyBytes))
	g.Use(Timeout(timeoutDuration, apperror.NewServiceUnavailable()))

	authRequired := TokenAuthMiddleware(s.Auth)
	// Data routes branch on the user's E2EE mode (docs/e2ee.md): the flag is
	// resolved once per request, after authentication.
	e2eeFlag := E2EEFlagMiddleware(s.E2EEFlags)

	// Per-IP throttling on the unauthenticated auth endpoints (anti-bruteforce
	// / anti-email-bombing). Tuned per endpoint.
	loginLimit := RateLimit(s.RateLimiter, "login", 10, time.Minute)
	refreshLimit := RateLimit(s.RateLimiter, "refresh", 30, time.Minute)
	challengeLimit := RateLimit(s.RateLimiter, "challenge", 30, time.Minute)
	resetLimit := RateLimit(s.RateLimiter, "reset", 5, time.Hour)

	g.POST("/registration", loginLimit, s.User.Registration)
	g.POST("/login", loginLimit, s.User.Login)
	g.POST("/logout", authRequired, s.User.Logout)
	g.POST("/refresh", refreshLimit, s.User.Refresh)
	g.PUT("/password", authRequired, s.User.UpdatePassword)
	g.POST("/resetPassword", resetLimit, s.User.ResetPassword)
	g.POST("/confirmResetPassword", resetLimit, s.User.ConfirmResetPassword)
	g.POST("/challenge", challengeLimit, s.User.Challenge)
	g.PUT("/secureAuth", authRequired, s.User.SecureAuth)

	g.GET("/categories", authRequired, e2eeFlag, s.Category.GetCategories)
	g.POST("/categories", authRequired, e2eeFlag, s.Category.CreateCategory)
	g.PATCH("/categories/:id", authRequired, e2eeFlag, s.Category.UpdateCategory)
	g.DELETE("/categories/:id", authRequired, e2eeFlag, s.Category.DeleteCategory)
	g.GET("/categories/:id/usage", authRequired, e2eeFlag, s.Category.GetCategoryUsage)

	g.POST("/tags", authRequired, e2eeFlag, s.Tag.CreateTag)
	g.PATCH("/tags/:id", authRequired, e2eeFlag, s.Tag.UpdateTag)
	g.DELETE("/tags/:id", authRequired, e2eeFlag, s.Tag.DeleteTag)
	g.GET("/tags/:id/usage", authRequired, e2eeFlag, s.Tag.GetTagUsage)

	g.GET("/events", authRequired, e2eeFlag, s.Event.GetEvents)
	g.POST("/events", authRequired, e2eeFlag, s.Event.CreateEvent)
	g.PATCH("/events/:id", authRequired, e2eeFlag, s.Event.UpdateEvent)
	g.DELETE("/events/:id", authRequired, e2eeFlag, s.Event.DeleteEvent)

	g.GET("/settings", authRequired, s.Settings.GetSettings)
	g.PUT("/settings", authRequired, s.Settings.UpdateSettings)

	g.POST("/e2ee/purge", authRequired, s.E2EE.Purge)

	// The migration payload is the user's whole dataset, so the endpoint gets
	// its own body cap and timeout, far above the API-wide defaults.
	m := router.Group(baseUrl)
	m.Use(MaxBodySize(e2eeMigrateMaxBodyBytes))
	m.Use(Timeout(e2eeMigrateTimeout, apperror.NewServiceUnavailable()))
	m.POST("/e2ee/migrate", authRequired, s.E2EE.Migrate)

	return router
}
