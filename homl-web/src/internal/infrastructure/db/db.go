package db

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/go-redis/redis/v7"
	_ "github.com/go-sql-driver/mysql" // imported for side effects only
	"github.com/joho/godotenv"
)

type DataSources struct {
	DB          *sql.DB
	RedisClient *redis.Client
}

func InitConfig() (*DataSources, error) {
	log.Printf("Initializing data sources\n")
	mysql, err := initMysql()
	if err != nil {
		return nil, fmt.Errorf("error opening db: %w", err)
	}

	rdb, err := initRedis()
	if err != nil {
		return nil, fmt.Errorf("error opening redix: %w", err)
	}

	return &DataSources{
		DB:          mysql,
		RedisClient: rdb,
	}, nil
}

func init() {
	LoadEnv()
}

// LoadEnv loads env vars from .env if present.
// It tries the current directory and then the parent directory.
func LoadEnv() {
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

func initMysql() (*sql.DB, error) {
	var err error

	address := os.Getenv("MYSQL_ADDRESS")
	user := os.Getenv("MYSQL_USER")
	pwd := os.Getenv("MYSQL_PASSWORD")
	dbName := os.Getenv("MYSQL_DATABASE")

	mySql, err := sql.Open("mysql", user+":"+pwd+"@tcp("+address+")/"+dbName+"?parseTime=true")
	if err != nil {
		return nil, err
	}

	err = mySql.Ping()
	if err != nil {
		return nil, err
	}

	return mySql, nil
}

func initRedis() (*redis.Client, error) {
	rdb := redis.NewClient(&redis.Options{
		Addr:     os.Getenv("REDIS_ADDRESS"),
		Password: os.Getenv("REDIS_PASSWORD"),
	})

	_, err := rdb.Ping().Result()
	if err != nil {
		return nil, err
	}

	return rdb, nil
}

// close to be used in graceful server shutdown
func (d *DataSources) Close() error {
	if err := d.DB.Close(); err != nil {
		return fmt.Errorf("error closing Mysql: %w", err)
	}

	if err := d.RedisClient.Close(); err != nil {
		return fmt.Errorf("error closing Redis: %w", err)
	}

	return nil
}
