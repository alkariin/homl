// Package config centralizes every environment read of the service. It is
// loaded once in main and injected into the infrastructure adapters, so no
// other package calls os.Getenv.
package config

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	Environment   string
	AccessSecret  string
	RefreshSecret string
	EncryptSecret string
	Host          string // public host used in password-reset links
	BaseURL       string // API route prefix (HOML_API_URL)
	CorsOrigin    string // allowed CORS origin ("*" when empty)

	HandlerTimeout time.Duration

	MysqlAddress  string
	MysqlUser     string
	MysqlPassword string
	MysqlDatabase string

	RedisAddress  string
	RedisPassword string
}

// Load reads the .env file if present, then materializes the configuration
// from the environment.
func Load() (*Config, error) {
	loadDotEnv()

	handlerTimeout := os.Getenv("HANDLER_TIMEOUT")
	ht, err := strconv.ParseInt(handlerTimeout, 0, 64)
	if err != nil {
		return nil, fmt.Errorf("could not parse HANDLER_TIMEOUT as int: %w", err)
	}

	return &Config{
		Environment:    os.Getenv("ENVIRONMENT"),
		AccessSecret:   os.Getenv("ACCESS_SECRET"),
		RefreshSecret:  os.Getenv("REFRESH_SECRET"),
		EncryptSecret:  os.Getenv("ENCRYPT_SECRET"),
		Host:           os.Getenv("HOST"),
		BaseURL:        os.Getenv("HOML_API_URL"),
		CorsOrigin:     os.Getenv("CORS_ORIGIN"),
		HandlerTimeout: time.Duration(ht) * time.Second,
		MysqlAddress:   os.Getenv("MYSQL_ADDRESS"),
		MysqlUser:      os.Getenv("MYSQL_USER"),
		MysqlPassword:  os.Getenv("MYSQL_PASSWORD"),
		MysqlDatabase:  os.Getenv("MYSQL_DATABASE"),
		RedisAddress:   os.Getenv("REDIS_ADDRESS"),
		RedisPassword:  os.Getenv("REDIS_PASSWORD"),
	}, nil
}

// IsDev reports whether the service runs in the development environment.
func (c *Config) IsDev() bool {
	return c.Environment == "DEV"
}

// loadDotEnv loads env vars from .env if present.
// It tries the current directory and then the parent directory.
func loadDotEnv() {
	cwd, err := os.Getwd()
	if err != nil {
		log.Printf("could not get working directory for .env lookup: %v", err)
		return
	}

	candidates := []string{
		filepath.Join(cwd, ".env"),
		filepath.Join(cwd, "..", ".env"),
	}

	for _, envPath := range candidates {
		if _, statErr := os.Stat(envPath); statErr == nil {
			if loadErr := godotenv.Load(envPath); loadErr != nil {
				log.Printf("could not load .env at %s: %v", envPath, loadErr)
			}
			return
		}
	}
}
