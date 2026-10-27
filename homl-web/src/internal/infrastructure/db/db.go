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

// How long startup waits for MySQL and Redis to answer. A host that boots
// (a NAS powering on) starts every container at once, ignoring compose's
// depends_on: MySQL then needs about a minute, and an API that exited at the
// first refused connection would crash-loop through the restart policy, each
// exit reported as a failure. Past this, startup fails and the restart
// policy takes over, so a wrong address or password still surfaces.
const (
	startupTimeout    = 2 * time.Minute
	startupFirstDelay = time.Second
	startupMaxDelay   = 10 * time.Second
)

func InitConfig(cfg *config.Config) (*DataSources, error) {
	log.Printf("Initializing data sources\n")
	var mysql *sqlx.DB
	err := retry("MySQL", startupTimeout, startupFirstDelay, startupMaxDelay, func() (err error) {
		mysql, err = initMysql(cfg)
		return err
	})
	if err != nil {
		return nil, fmt.Errorf("error opening db: %w", err)
	}

	var rdb *redis.Client
	err = retry("Redis", startupTimeout, startupFirstDelay, startupMaxDelay, func() (err error) {
		rdb, err = initRedis(cfg)
		return err
	})
	if err != nil {
		mysql.Close()
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
		rdb.Close() // each retry builds its own client
		return nil, err
	}

	return rdb, nil
}

// retry calls attempt until it succeeds or timeout has passed, sleeping
// between tries from firstDelay, doubled each time up to maxDelay, and logging
// why each try failed. Once the next sleep would end past the timeout, it
// returns the last error.
func retry(name string, timeout, firstDelay, maxDelay time.Duration, attempt func() error) error {
	deadline := time.Now().Add(timeout)
	delay := firstDelay
	for {
		err := attempt()
		if err == nil {
			return nil
		}
		if time.Now().Add(delay).After(deadline) {
			return err
		}
		log.Printf("%s not reachable yet, retrying in %v: %v\n", name, delay, err)
		time.Sleep(delay)
		delay = min(delay*2, maxDelay)
	}
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
