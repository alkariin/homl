package db

import (
	"context"
	"fmt"
	"log"
	"time"

	_ "github.com/go-sql-driver/mysql" // imported for side effects only
	"github.com/jmoiron/sqlx"
	"github.com/redis/go-redis/v9"

	"github.com/alkariin/homl/homl-web/internal/infrastructure/config"
)

type DataSources struct {
	DB          *sqlx.DB
	RedisClient *redis.Client
}

func InitConfig(cfg *config.Config) (*DataSources, error) {
	log.Printf("Initializing data sources\n")
	mysql, err := initMysql(cfg)
	if err != nil {
		return nil, fmt.Errorf("error opening db: %w", err)
	}

	rdb, err := initRedis(cfg)
	if err != nil {
		return nil, fmt.Errorf("error opening redis: %w", err)
	}

	return &DataSources{
		DB:          mysql,
		RedisClient: rdb,
	}, nil
}

func initMysql(cfg *config.Config) (*sqlx.DB, error) {
	mySql, err := sqlx.Connect("mysql", cfg.MysqlUser+":"+cfg.MysqlPassword+"@tcp("+cfg.MysqlAddress+")/"+cfg.MysqlDatabase+"?parseTime=true")
	if err != nil {
		return nil, err
	}

	// keep lifetime below the MySQL server timeout so the driver never uses a closed connection
	mySql.SetMaxOpenConns(25)
	mySql.SetMaxIdleConns(25)
	mySql.SetConnMaxLifetime(3 * time.Minute)

	return mySql, nil
}

func initRedis(cfg *config.Config) (*redis.Client, error) {
	rdb := redis.NewClient(&redis.Options{
		Addr:     cfg.RedisAddress,
		Password: cfg.RedisPassword,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := rdb.Ping(ctx).Result()
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
