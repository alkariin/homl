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
	"strings"
	"time"

	"github.com/joho/godotenv"
)

// minSecretLength is the minimum accepted length for the JWT/encryption
// secrets. Anything shorter is rejected at startup.
const minSecretLength = 32

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

	SmtpHost     string
	SmtpPort     string
	SmtpFrom     string
	SmtpUser     string // auth identity; defaults to SmtpFrom when empty
	SmtpPassword string
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

	cfg := &Config{
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
		SmtpHost:       os.Getenv("SMTP_HOST"),
		SmtpPort:       os.Getenv("SMTP_PORT"),
		SmtpFrom:       os.Getenv("SMTP_FROM"),
		SmtpUser:       os.Getenv("SMTP_USER"),
		SmtpPassword:   os.Getenv("SMTP_PASSWORD"),
	}

	if err := cfg.validate(); err != nil {
		return nil, err
	}

	if !cfg.isProd() {
		log.Printf("WARNING: ENVIRONMENT is %q, not PROD — tokens are longer-lived and gin runs in debug mode. Do not use this in production.", cfg.Environment)
	}

	return cfg, nil
}

// validate rejects configurations that would silently weaken security: unset,
// placeholder or too-short secrets, and (outside DEV) a wildcard/empty CORS
// origin.
func (c *Config) validate() error {
	secrets := map[string]string{
		"ACCESS_SECRET":  c.AccessSecret,
		"REFRESH_SECRET": c.RefreshSecret,
		"ENCRYPT_SECRET": c.EncryptSecret,
	}
	for name, value := range secrets {
		if value == "" {
			return fmt.Errorf("%s must be set", name)
		}
		if strings.Contains(value, "change_me") {
			return fmt.Errorf("%s still holds a placeholder value; set a real secret", name)
		}
		if len(value) < minSecretLength {
			return fmt.Errorf("%s must be at least %d characters", name, minSecretLength)
		}
	}

	if !c.IsDev() {
		if c.CorsOrigin == "" || c.CorsOrigin == "*" {
			return fmt.Errorf("CORS_ORIGIN must be an explicit origin outside DEV (got %q)", c.CorsOrigin)
		}
	}

	return nil
}

// IsDev reports whether the service runs in the development environment.
func (c *Config) IsDev() bool {
	return c.Environment == "DEV"
}

func (c *Config) isProd() bool {
	return c.Environment == "PROD"
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
