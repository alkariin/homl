package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/db"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/persistence"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/web"
)

func inject(d *db.DataSources) (*gin.Engine, error) {
	log.Println("Injecting data sources")

	// repositories
	categoriesRepository := persistence.NewCategoriesRepository(d.DB)
	eventsRepository := persistence.NewEventsRepository(d.DB)
	personsRepository := persistence.NewPersonsRepository(d.DB)
	settingsRepository := persistence.NewSettingsRepository(d.DB)
	tagsRepository := persistence.NewTagsRepository(d.DB)
	usersRepository := persistence.NewUsersRepository(d.DB, d.RedisClient)

	// services
	categoriesService := application.NewCategoriesService(&application.CSConfig{
		CategoriesRepository: categoriesRepository,
	})
	eventsService := application.NewEventsService(&application.ESConfig{
		EventsRepository:     eventsRepository,
		CategoriesRepository: categoriesRepository,
		TagsRepository:       tagsRepository,
	})
	personService := application.NewPersonsService(&application.PSConfig{
		PersonsRepository:    personsRepository,
		CategoriesRepository: categoriesRepository,
		TagsRepository:       tagsRepository,
	})
	settingsService := application.NewSettingsService(&application.SSConfig{
		SettingsRepository: settingsRepository,
	})
	tagsService := application.NewTagsService(&application.TSConfig{
		TagsRepository:       tagsRepository,
		CategoriesRepository: categoriesRepository,
	})
	usersService := application.NewUsersService(&application.UserConfig{
		UsersRepository: usersRepository,
	})

	// wire the per-feature HTTP handlers (usersService doubles as the Authenticator)
	server := &web.Server{
		User:     &web.UserHandler{UsersService: usersService},
		Category: &web.CategoryHandler{CategoriesService: categoriesService, UsersService: usersService},
		Tag:      &web.TagHandler{TagsService: tagsService, UsersService: usersService},
		Person:   &web.PersonHandler{PersonsService: personService, UsersService: usersService},
		Event:    &web.EventHandler{EventsService: eventsService, UsersService: usersService},
		Settings: &web.SettingsHandler{SettingsService: settingsService, UsersService: usersService},
	}

	baseURL := os.Getenv("HOML_API_URL")

	handlerTimeout := os.Getenv("HANDLER_TIMEOUT")
	ht, err := strconv.ParseInt(handlerTimeout, 0, 64)
	if err != nil {
		return nil, fmt.Errorf("could not parse HANDLER_TIMEOUT as int: %w", err)
	}
	TimeoutDuration := time.Duration(time.Duration(ht) * time.Second)

	router := web.SetupRouter(server, baseURL, TimeoutDuration)

	return router, nil
}

func main() {
	ds, err := db.InitConfig()
	if err != nil {
		log.Fatalf("Unable to initialize data sources: %v\n", err)
	}

	router, err := inject(ds)
	if err != nil {
		log.Fatalf("Failure to inject data sources: %v\n", err)
	}

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
