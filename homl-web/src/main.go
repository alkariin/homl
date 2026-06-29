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

	"github.com/alkariin/homl/homl-web/config"
	"github.com/alkariin/homl/homl-web/controller"
	"github.com/alkariin/homl/homl-web/repository"
	"github.com/alkariin/homl/homl-web/service"
)

func inject(d *config.DataSources) (*gin.Engine, error) {
	log.Println("Injecting data sources")

	// repositories
	categoriesRepository := repository.NewCategoriesRepository(d.DB)
	eventsRepository := repository.NewEventsRepository(d.DB)
	personsRepository := repository.NewPersonsRepository(d.DB)
	settingsRepository := repository.NewSettingsRepository(d.DB)
	tagsRepository := repository.NewTagsRepository(d.DB)
	usersRepository := repository.NewUsersRepository(d.DB, d.RedisClient)

	// services
	categoriesService := service.NewCategoriesService(&service.CSConfig{
		CategoriesRepository: categoriesRepository,
	})
	eventsService := service.NewEventsService(&service.ESConfig{
		EventsRepository:     eventsRepository,
		CategoriesRepository: categoriesRepository,
		TagsRepository:       tagsRepository,
	})
	personService := service.NewPersonsService(&service.PSConfig{
		PersonsRepository:    personsRepository,
		CategoriesRepository: categoriesRepository,
		TagsRepository:       tagsRepository,
	})
	settingsService := service.NewSettingsService(&service.SSConfig{
		SettingsRepository: settingsRepository,
	})
	tagsService := service.NewTagsService(&service.TSConfig{
		TagsRepository:       tagsRepository,
		CategoriesRepository: categoriesRepository,
	})
	usersService := service.NewUsersService(&service.UserConfig{
		UsersRepository: usersRepository,
	})

	// create handler and rest of config
	handler := &controller.Handler{
		CategoriesService: categoriesService,
		EventsService:     eventsService,
		PersonsService:    personService,
		SettingsService:   settingsService,
		TagsService:       tagsService,
		UsersService:      usersService,
	}

	baseURL := os.Getenv("HOML_API_URL")

	handlerTimeout := os.Getenv("HANDLER_TIMEOUT")
	ht, err := strconv.ParseInt(handlerTimeout, 0, 64)
	if err != nil {
		return nil, fmt.Errorf("could not parse HANDLER_TIMEOUT as int: %w", err)
	}
	TimeoutDuration := time.Duration(time.Duration(ht) * time.Second)

	router := SetupRouter(handler, baseURL, TimeoutDuration)

	return router, nil
}

func main() {
	ds, err := config.InitConfig()
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
