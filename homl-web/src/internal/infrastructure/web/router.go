package web

import (
	"time"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/env"
	"github.com/gin-gonic/gin"
)

// Server groups the per-feature HTTP handlers wired into the router.
type Server struct {
	User     *UserHandler
	Category *CategoryHandler
	Tag      *TagHandler
	Person   *PersonHandler
	Event    *EventHandler
	Settings *SettingsHandler
}

func SetupRouter(s *Server, baseUrl string, timeoutDuration time.Duration) *gin.Engine {
	router := gin.Default()
	router.Use(CorsMiddleware())

	g := router.Group(baseUrl)
	g.Use(Timeout(timeoutDuration, apperror.NewServiceUnavailable()))

	if !env.IsDev() {
		gin.SetMode(gin.ReleaseMode)
	}

	g.POST("/registration", s.User.Registration)
	g.POST("/login", s.User.Login)
	g.POST("/logout", TokenAuthMiddleware(), s.User.Logout)
	g.POST("/refresh", s.User.Refresh)
	g.PUT("/password", TokenAuthMiddleware(), s.User.UpdatePassword)
	g.POST("/resetPassword", s.User.ResetPassword)
	g.POST("/confirmResetPassword", TokenAuthMiddleware(), s.User.ConfirmResetPassword)
	g.GET("/challenge", s.User.Challenge)
	g.PUT("/secureAuth", TokenAuthMiddleware(), s.User.SecureAuth)

	g.GET("/categories", TokenAuthMiddleware(), s.Category.GetCategories)
	g.POST("/categories", TokenAuthMiddleware(), s.Category.CreateCategory)
	g.PATCH("/categories/:id", TokenAuthMiddleware(), s.Category.UpdateCategory)
	g.DELETE("/categories/:id", TokenAuthMiddleware(), s.Category.DeleteCategory)

	g.POST("/tags", TokenAuthMiddleware(), s.Tag.CreateTag)
	g.PATCH("/tags/:id", TokenAuthMiddleware(), s.Tag.UpdateTag)
	g.DELETE("/tags/:id", TokenAuthMiddleware(), s.Tag.DeleteTag)

	g.GET("/persons", TokenAuthMiddleware(), s.Person.GetPersons)
	g.POST("/persons", TokenAuthMiddleware(), s.Person.CreatePerson)
	g.PATCH("/persons/:id", TokenAuthMiddleware(), s.Person.UpdatePerson)
	g.DELETE("/persons/:id", TokenAuthMiddleware(), s.Person.DeletePerson)

	g.GET("/events", TokenAuthMiddleware(), s.Event.GetEvents)
	g.POST("/events", TokenAuthMiddleware(), s.Event.CreateEvent)
	g.PATCH("/events/:id", TokenAuthMiddleware(), s.Event.UpdateEvent)
	g.DELETE("/events/:id", TokenAuthMiddleware(), s.Event.DeleteEvent)

	g.GET("/settings", TokenAuthMiddleware(), s.Settings.GetSettings)
	g.PUT("/settings", TokenAuthMiddleware(), s.Settings.UpdateSettings)

	return router
}
