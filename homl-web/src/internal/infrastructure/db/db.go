package db

import (
	"database/sql"
	"fmt"
	"log"

	"github.com/go-redis/redis/v7"
	_ "github.com/go-sql-driver/mysql" // imported for side effects only

	"github.com/alkariin/homl/homl-web/internal/infrastructure/config"
)

type DataSources struct {
	DB          *sql.DB
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

func initMysql(cfg *config.Config) (*sql.DB, error) {
	mySql, err := sql.Open("mysql", cfg.MysqlUser+":"+cfg.MysqlPassword+"@tcp("+cfg.MysqlAddress+")/"+cfg.MysqlDatabase+"?parseTime=true")
	if err != nil {
		return nil, err
	}

	err = mySql.Ping()
	if err != nil {
		return nil, err
	}

	return mySql, nil
}

func initRedis(cfg *config.Config) (*redis.Client, error) {
	rdb := redis.NewClient(&redis.Options{
		Addr:     cfg.RedisAddress,
		Password: cfg.RedisPassword,
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
