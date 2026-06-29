package main

import (
	"time"

	"github.com/alkariin/homl/homl-web/config"
	"github.com/alkariin/homl/homl-web/controller"
	"github.com/alkariin/homl/homl-web/helper"
	"github.com/gin-gonic/gin"
)

func SetupRouter(handler *controller.Handler, baseUrl string, timeoutDuration time.Duration) *gin.Engine {
	router := gin.Default()
	router.Use(helper.CorsMiddleware())

	g := router.Group(baseUrl)
	g.Use(helper.Timeout(timeoutDuration, helper.NewServiceUnavailable()))

	if !config.IsDev() {
		gin.SetMode(gin.ReleaseMode)
	}

	g.POST("/registration", handler.Registration)
	g.POST("/login", handler.Login)
	g.POST("/logout", helper.TokenAuthMiddleware(), handler.Logout)
	g.POST("/refresh", handler.Refresh)
	g.PUT("/password", helper.TokenAuthMiddleware(), handler.UpdatePassword)
	g.POST("/resetPassword", handler.ResetPassword)
	g.POST("/confirmResetPassword", helper.TokenAuthMiddleware(), handler.ConfirmResetPassword)
	g.GET("/challenge", handler.Challenge)
	g.PUT("/secureAuth", helper.TokenAuthMiddleware(), handler.SecureAuth)

	g.GET("/categories", helper.TokenAuthMiddleware(), handler.GetCategories)
	g.POST("/categories", helper.TokenAuthMiddleware(), handler.CreateCategory)
	g.PATCH("/categories/:id", helper.TokenAuthMiddleware(), handler.UpdateCategory)
	g.DELETE("/categories/:id", helper.TokenAuthMiddleware(), handler.DeleteCategory)

	g.POST("/tags", helper.TokenAuthMiddleware(), handler.CreateTag)
	g.PATCH("/tags/:id", helper.TokenAuthMiddleware(), handler.UpdateTag)
	g.DELETE("/tags/:id", helper.TokenAuthMiddleware(), handler.DeleteTag)

	g.GET("/persons", helper.TokenAuthMiddleware(), handler.GetPersons)
	g.POST("/persons", helper.TokenAuthMiddleware(), handler.CreatePerson)
	g.PATCH("/persons/:id", helper.TokenAuthMiddleware(), handler.UpdatePerson)
	g.DELETE("/persons/:id", helper.TokenAuthMiddleware(), handler.DeletePerson)

	g.GET("/events", helper.TokenAuthMiddleware(), handler.GetEvents)
	g.POST("/events", helper.TokenAuthMiddleware(), handler.CreateEvent)
	g.PATCH("/events/:id", helper.TokenAuthMiddleware(), handler.UpdateEvent)
	g.DELETE("/events/:id", helper.TokenAuthMiddleware(), handler.DeleteEvent)

	g.GET("/settings", helper.TokenAuthMiddleware(), handler.GetSettings)
	g.PUT("/settings", helper.TokenAuthMiddleware(), handler.UpdateSettings)

	return router
}
