package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/auth"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/config"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/crypto"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/db"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/persistence"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/web"
)

func inject(cfg *config.Config, d *db.DataSources) *gin.Engine {
	log.Println("Injecting data sources")

	// infrastructure adapters
	aes := crypto.NewAES(cfg.EncryptSecret)
	jwt := auth.NewJWT(cfg.AccessSecret, cfg.RefreshSecret, cfg.IsDev())

	// repositories
	categoriesRepository := persistence.NewCategoriesRepository(d.DB, aes)
	eventsRepository := persistence.NewEventsRepository(d.DB, aes)
	personsRepository := persistence.NewPersonsRepository(d.DB, aes)
	usersRepository := persistence.NewUsersRepository(d.DB, d.RedisClient, aes)

	// services
	categoriesService := application.NewCategoriesService(&application.CSConfig{
		CategoriesRepository: categoriesRepository,
		Crypto:               aes,
	})
	eventsService := application.NewEventsService(&application.ESConfig{
		EventsRepository:     eventsRepository,
		CategoriesRepository: categoriesRepository,
		Crypto:               aes,
	})
	personService := application.NewPersonsService(&application.PSConfig{
		PersonsRepository:    personsRepository,
		CategoriesRepository: categoriesRepository,
		Crypto:               aes,
	})
	settingsService := application.NewSettingsService(&application.SSConfig{
		UsersRepository: usersRepository,
	})
	tagsService := application.NewTagsService(&application.TSConfig{
		CategoriesRepository: categoriesRepository,
		Crypto:               aes,
	})
	usersService := application.NewUsersService(&application.UserConfig{
		UsersRepository: usersRepository,
		Tokens:          jwt,
		Host:            cfg.Host,
	})

	// request-level authentication: parse the token, resolve the session
	authenticator := &web.TokenAuthenticator{Tokens: jwt, Sessions: usersRepository}

	// wire the per-feature HTTP handlers
	server := &web.Server{
		Tokens:   jwt,
		User:     &web.UserHandler{UsersService: usersService, Tokens: jwt, Auth: authenticator},
		Category: &web.CategoryHandler{CategoriesService: categoriesService, Auth: authenticator},
		Tag:      &web.TagHandler{TagsService: tagsService, Auth: authenticator},
		Person:   &web.PersonHandler{PersonsService: personService, Auth: authenticator},
		Event:    &web.EventHandler{EventsService: eventsService, Auth: authenticator},
		Settings: &web.SettingsHandler{SettingsService: settingsService, Auth: authenticator},
	}

	return web.SetupRouter(server, cfg.BaseURL, cfg.HandlerTimeout, cfg.IsDev(), cfg.CorsOrigin)
}

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Unable to load configuration: %v\n", err)
	}

	ds, err := db.InitConfig(cfg)
	if err != nil {
		log.Fatalf("Unable to initialize data sources: %v\n", err)
	}

	router := inject(cfg, ds)

	srv := &http.Server{
		Addr:    ":8080",
		Handler: router,
	}

	// Graceful server shutdown - https://github.com/gin-gonic/examples/blob/master/graceful-shutdown/graceful-shutdown/server.go
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to initialize server: %v\n", err)
		}
	}()

	log.Printf("Listening on port %v\n", srv.Addr)

	// Wait for kill signal of channel
	quit := make(chan os.Signal, 1)

	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	// This blocks until a signal is passed into the quit channel
	<-quit

	// The context is used to inform the server it has 5 seconds to finish
	// the request it is currently handling
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// shutdown data sources
	if err := ds.Close(); err != nil {
		log.Fatalf("A problem occurred gracefully shutting down data sources: %v\n", err)
	}

	// Shutdown server
	log.Println("Shutting down server...")
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v\n", err)
	}
}
