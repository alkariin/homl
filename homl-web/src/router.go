package main

import (
	"time"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/homl/homl-web/internal/category"
	"github.com/alkariin/homl/homl-web/internal/event"
	"github.com/alkariin/homl/homl-web/internal/person"
	"github.com/alkariin/homl/homl-web/internal/settings"
	"github.com/alkariin/homl/homl-web/internal/shared"
	"github.com/alkariin/homl/homl-web/internal/tag"
	"github.com/alkariin/homl/homl-web/internal/user"
)

// Server groups the per-feature HTTP handlers wired into the router.
type Server struct {
	User     *user.Handler
	Category *category.Handler
	Tag      *tag.Handler
	Person   *person.Handler
	Event    *event.Handler
	Settings *settings.Handler
}

func SetupRouter(s *Server, baseUrl string, timeoutDuration time.Duration) *gin.Engine {
	router := gin.Default()
	router.Use(shared.CorsMiddleware())

	g := router.Group(baseUrl)
	g.Use(shared.Timeout(timeoutDuration, shared.NewServiceUnavailable()))

	if !shared.IsDev() {
		gin.SetMode(gin.ReleaseMode)
	}

	g.POST("/registration", s.User.Registration)
	g.POST("/login", s.User.Login)
	g.POST("/logout", shared.TokenAuthMiddleware(), s.User.Logout)
	g.POST("/refresh", s.User.Refresh)
	g.PUT("/password", shared.TokenAuthMiddleware(), s.User.UpdatePassword)
	g.POST("/resetPassword", s.User.ResetPassword)
	g.POST("/confirmResetPassword", shared.TokenAuthMiddleware(), s.User.ConfirmResetPassword)
	g.GET("/challenge", s.User.Challenge)
	g.PUT("/secureAuth", shared.TokenAuthMiddleware(), s.User.SecureAuth)

	g.GET("/categories", shared.TokenAuthMiddleware(), s.Category.GetCategories)
	g.POST("/categories", shared.TokenAuthMiddleware(), s.Category.CreateCategory)
	g.PATCH("/categories/:id", shared.TokenAuthMiddleware(), s.Category.UpdateCategory)
	g.DELETE("/categories/:id", shared.TokenAuthMiddleware(), s.Category.DeleteCategory)

	g.POST("/tags", shared.TokenAuthMiddleware(), s.Tag.CreateTag)
	g.PATCH("/tags/:id", shared.TokenAuthMiddleware(), s.Tag.UpdateTag)
	g.DELETE("/tags/:id", shared.TokenAuthMiddleware(), s.Tag.DeleteTag)

	g.GET("/persons", shared.TokenAuthMiddleware(), s.Person.GetPersons)
	g.POST("/persons", shared.TokenAuthMiddleware(), s.Person.CreatePerson)
	g.PATCH("/persons/:id", shared.TokenAuthMiddleware(), s.Person.UpdatePerson)
	g.DELETE("/persons/:id", shared.TokenAuthMiddleware(), s.Person.DeletePerson)

	g.GET("/events", shared.TokenAuthMiddleware(), s.Event.GetEvents)
	g.POST("/events", shared.TokenAuthMiddleware(), s.Event.CreateEvent)
	g.PATCH("/events/:id", shared.TokenAuthMiddleware(), s.Event.UpdateEvent)
	g.DELETE("/events/:id", shared.TokenAuthMiddleware(), s.Event.DeleteEvent)

	g.GET("/settings", shared.TokenAuthMiddleware(), s.Settings.GetSettings)
	g.PUT("/settings", shared.TokenAuthMiddleware(), s.Settings.UpdateSettings)

	return router
}
