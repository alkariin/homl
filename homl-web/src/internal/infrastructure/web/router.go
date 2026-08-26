package web

import (
	"log"
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

// e2eeMigrateWriteGrace is the extra time granted to write the response once
// the handler has used its full budget. Deadlines are absolute, so the write
// one has to cover the handler itself plus the response.
const e2eeMigrateWriteGrace = 15 * time.Second

// Deadlines raises the connection read/write deadlines of a single route
// above the server-wide ReadTimeout/WriteTimeout set in main.go.
//
// Those server timeouts are absolute per-connection deadlines that a handler
// timeout cannot lift on its own: without this, the migration's 60 s budget
// is silently cut short by the 20 s WriteTimeout, and its 32 MiB body by the
// 10 s ReadTimeout. Must run *before* Timeout, whose writer wrapper hides the
// underlying connection from the response controller.
func Deadlines(read, write time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		rc := http.NewResponseController(c.Writer)
		now := time.Now()
		// A failure here is not fatal — the request simply stays under the
		// server-wide timeouts — but it silently reinstates the very cap this
		// middleware exists to lift, so it must not pass unnoticed.
		if err := rc.SetReadDeadline(now.Add(read)); err != nil {
			log.Printf("deadlines: cannot extend the read deadline: %v", err)
		}
		if err := rc.SetWriteDeadline(now.Add(write)); err != nil {
			log.Printf("deadlines: cannot extend the write deadline: %v", err)
		}
		c.Next()
	}
}

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

func SetupRouter(s *Server, baseUrl string, timeoutDuration time.Duration, isDev bool, corsOrigin string, trustedProxies []string) *gin.Engine {
	if !isDev {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()
	// Only the configured proxies may set X-Forwarded-For: trusting any peer
	// would let a client spoof its address and walk past the per-IP rate
	// limits on the auth endpoints. Empty (the default) trusts none, which is
	// right for a directly exposed service — but behind a reverse proxy it
	// makes every request share the proxy's address, and with it a single
	// rate-limit budget, so TRUSTED_PROXIES must then list the proxy.
	// Values are validated by the config loader.
	if err := router.SetTrustedProxies(trustedProxies); err != nil {
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
	// Destructive and password-gated, so it shares the per-IP /login budget: a
	// leaked access token must not buy unlimited password guesses here.
	g.DELETE("/account", loginLimit, authRequired, s.User.DeleteAccount)

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
	// its own body cap and timeout, far above the API-wide defaults. The
	// connection deadlines are raised first, otherwise the server-wide ones
	// would cap both.
	m := router.Group(baseUrl)
	m.Use(Deadlines(e2eeMigrateTimeout, e2eeMigrateTimeout+e2eeMigrateWriteGrace))
	m.Use(MaxBodySize(e2eeMigrateMaxBodyBytes))
	m.Use(Timeout(e2eeMigrateTimeout, apperror.NewServiceUnavailable()))
	m.POST("/e2ee/migrate", authRequired, s.E2EE.Migrate)

	return router
}
