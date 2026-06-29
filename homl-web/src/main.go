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

	"github.com/alkariin/homl/homl-web/internal/category"
	"github.com/alkariin/homl/homl-web/internal/event"
	"github.com/alkariin/homl/homl-web/internal/person"
	"github.com/alkariin/homl/homl-web/internal/platform"
	"github.com/alkariin/homl/homl-web/internal/settings"
	"github.com/alkariin/homl/homl-web/internal/tag"
	"github.com/alkariin/homl/homl-web/internal/user"
)

func inject(d *platform.DataSources) (*gin.Engine, error) {
	log.Println("Injecting data sources")

	// repositories
	categoriesRepository := category.NewCategoriesRepository(d.DB)
	eventsRepository := event.NewEventsRepository(d.DB)
	personsRepository := person.NewPersonsRepository(d.DB)
	settingsRepository := settings.NewSettingsRepository(d.DB)
	tagsRepository := tag.NewTagsRepository(d.DB)
	usersRepository := user.NewUsersRepository(d.DB, d.RedisClient)

	// services
	categoriesService := category.NewCategoriesService(&category.CSConfig{
		CategoriesRepository: categoriesRepository,
	})
	eventsService := event.NewEventsService(&event.ESConfig{
		EventsRepository:     eventsRepository,
		CategoriesRepository: categoriesRepository,
		TagsRepository:       tagsRepository,
	})
	personService := person.NewPersonsService(&person.PSConfig{
		PersonsRepository:    personsRepository,
		CategoriesRepository: categoriesRepository,
		TagsRepository:       tagsRepository,
	})
	settingsService := settings.NewSettingsService(&settings.SSConfig{
		SettingsRepository: settingsRepository,
	})
	tagsService := tag.NewTagsService(&tag.TSConfig{
		TagsRepository:       tagsRepository,
		CategoriesRepository: categoriesRepository,
	})
	usersService := user.NewUsersService(&user.UserConfig{
		UsersRepository: usersRepository,
	})

	// wire the per-feature HTTP handlers (usersService doubles as the Authenticator)
	server := &Server{
		User:     &user.Handler{UsersService: usersService},
		Category: &category.Handler{CategoriesService: categoriesService, UsersService: usersService},
		Tag:      &tag.Handler{TagsService: tagsService, UsersService: usersService},
		Person:   &person.Handler{PersonsService: personService, UsersService: usersService},
		Event:    &event.Handler{EventsService: eventsService, UsersService: usersService},
		Settings: &settings.Handler{SettingsService: settingsService, UsersService: usersService},
	}

	baseURL := os.Getenv("HOML_API_URL")

	handlerTimeout := os.Getenv("HANDLER_TIMEOUT")
	ht, err := strconv.ParseInt(handlerTimeout, 0, 64)
	if err != nil {
		return nil, fmt.Errorf("could not parse HANDLER_TIMEOUT as int: %w", err)
	}
	TimeoutDuration := time.Duration(time.Duration(ht) * time.Second)

	router := SetupRouter(server, baseURL, TimeoutDuration)

	return router, nil
}

func main() {
	ds, err := platform.InitConfig()
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
