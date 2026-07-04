package web

import (
	"time"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/gin-gonic/gin"
)

// Server groups the per-feature HTTP handlers wired into the router, plus the
// token parser backing the auth middleware.
type Server struct {
	Tokens   TokenParser
	User     *UserHandler
	Category *CategoryHandler
	Tag      *TagHandler
	Person   *PersonHandler
	Event    *EventHandler
	Settings *SettingsHandler
}

func SetupRouter(s *Server, baseUrl string, timeoutDuration time.Duration, isDev bool, corsOrigin string) *gin.Engine {
	if !isDev {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()
	router.Use(CorsMiddleware(corsOrigin))

	g := router.Group(baseUrl)
	g.Use(Timeout(timeoutDuration, apperror.NewServiceUnavailable()))

	authRequired := TokenAuthMiddleware(s.Tokens)

	g.POST("/registration", s.User.Registration)
	g.POST("/login", s.User.Login)
	g.POST("/logout", authRequired, s.User.Logout)
	g.POST("/refresh", s.User.Refresh)
	g.PUT("/password", authRequired, s.User.UpdatePassword)
	g.POST("/resetPassword", s.User.ResetPassword)
	g.POST("/confirmResetPassword", authRequired, s.User.ConfirmResetPassword)
	g.GET("/challenge", s.User.Challenge)
	g.PUT("/secureAuth", authRequired, s.User.SecureAuth)

	g.GET("/categories", authRequired, s.Category.GetCategories)
	g.POST("/categories", authRequired, s.Category.CreateCategory)
	g.PATCH("/categories/:id", authRequired, s.Category.UpdateCategory)
	g.DELETE("/categories/:id", authRequired, s.Category.DeleteCategory)

	g.POST("/tags", authRequired, s.Tag.CreateTag)
	g.PATCH("/tags/:id", authRequired, s.Tag.UpdateTag)
	g.DELETE("/tags/:id", authRequired, s.Tag.DeleteTag)

	g.GET("/persons", authRequired, s.Person.GetPersons)
	g.POST("/persons", authRequired, s.Person.CreatePerson)
	g.PATCH("/persons/:id", authRequired, s.Person.UpdatePerson)
	g.DELETE("/persons/:id", authRequired, s.Person.DeletePerson)

	g.GET("/events", authRequired, s.Event.GetEvents)
	g.POST("/events", authRequired, s.Event.CreateEvent)
	g.PATCH("/events/:id", authRequired, s.Event.UpdateEvent)
	g.DELETE("/events/:id", authRequired, s.Event.DeleteEvent)

	g.GET("/settings", authRequired, s.Settings.GetSettings)
	g.PUT("/settings", authRequired, s.Settings.UpdateSettings)

	return router
}
