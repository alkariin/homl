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
	"github.com/alkariin/homl/homl-web/internal/infrastructure/mail"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/persistence"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/ratelimit"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/web"
)

func inject(cfg *config.Config, d *db.DataSources) *gin.Engine {
	log.Println("Injecting data sources")

	// infrastructure adapters
	aes := crypto.NewKeyring(cfg.EncryptSecret)
	jwt := auth.NewJWT(cfg.AccessSecret, cfg.RefreshSecret, cfg.IsDev())
	limiter := ratelimit.NewRedisLimiter(d.RedisClient)

	// repositories
	categoriesRepository := persistence.NewCategoriesRepository(d.DB, aes)
	eventsRepository := persistence.NewEventsRepository(d.DB, aes)
	usersRepository := persistence.NewUsersRepository(d.DB, d.RedisClient, aes)
	e2eeRepository := persistence.NewE2EERepository(d.DB, aes)

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
	settingsService := application.NewSettingsService(&application.SSConfig{
		UsersRepository: usersRepository,
	})
	tagsService := application.NewTagsService(&application.TSConfig{
		CategoriesRepository: categoriesRepository,
		Crypto:               aes,
	})
	e2eeService := application.NewE2EEService(&application.E2EEConfig{
		E2EERepository: e2eeRepository,
	})
	// Without SMTP configured, reset codes are logged instead of emailed — the
	// usual DEV setup. A configured host wins even in DEV, so the real SMTP
	// path and its localized templates can be exercised against a local
	// catcher (see docs/auth-flows.md) instead of first running in production.
	var mailer application.Mailer = &mail.LogMailer{}
	if cfg.SmtpHost != "" {
		// Sending is detached from the request on purpose: see mail.AsyncMailer.
		mailer = mail.NewAsyncMailer(&mail.SMTPMailer{
			Host:     cfg.SmtpHost,
			Port:     cfg.SmtpPort,
			From:     cfg.SmtpFrom,
			User:     cfg.SmtpUser,
			Password: cfg.SmtpPassword,
		})
	}

	usersService := application.NewUsersService(&application.UserConfig{
		UsersRepository: usersRepository,
		Tokens:          jwt,
		Mailer:          mailer,
	})

	// request-level authentication: parse the token, resolve the session
	authenticator := &web.TokenAuthenticator{Tokens: jwt, Sessions: usersRepository}

	// wire the per-feature HTTP handlers
	server := &web.Server{
		Auth:        authenticator,
		RateLimiter: limiter,
		E2EEFlags:   e2eeRepository,
		Health: &web.HealthHandler{
			CheckDB: d.DB.PingContext,
			CheckRedis: func(ctx context.Context) error {
				return d.RedisClient.Ping(ctx).Err()
			},
		},
		User:     &web.UserHandler{UsersService: usersService, Tokens: jwt},
		Category: &web.CategoryHandler{CategoriesService: categoriesService},
		Tag:      &web.TagHandler{TagsService: tagsService},
		Event:    &web.EventHandler{EventsService: eventsService},
		Settings: &web.SettingsHandler{SettingsService: settingsService},
		E2EE:     &web.E2EEHandler{E2EEService: e2eeService},
	}

	return web.SetupRouter(server, cfg.BaseURL, cfg.HandlerTimeout, cfg.IsDev(), cfg.CorsOrigin, cfg.TrustedProxies)
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
		// Bound how long a client may take to send its request so a slow or
		// malicious peer cannot pin connections open indefinitely (slowloris).
		// The per-handler business timeout is enforced separately by the
		// Timeout middleware.
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      20 * time.Second,
		IdleTimeout:       60 * time.Second,
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

	// Shutdown the server first so in-flight requests finish while the data
	// sources are still open, then close the pools.
	log.Println("Shutting down server...")
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("Server forced to shutdown: %v\n", err)
	}

	if err := ds.Close(); err != nil {
		log.Printf("A problem occurred gracefully shutting down data sources: %v\n", err)
	}
}
