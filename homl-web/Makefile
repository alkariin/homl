ifneq (,$(wildcard .env))
include .env
export
endif

ifneq (,$(wildcard .env.local))
include .env.local
export
endif

ifneq (,$(wildcard Makefile.local))
include Makefile.local
endif

APP_IMAGE          ?= homlback
DOCKER_NETWORK     ?= homlNet
COMPOSE_LOCAL_FILE ?= docker-compose.local.yml
COMPOSE_FILES       = -f docker-compose.yml $(if $(wildcard $(COMPOSE_LOCAL_FILE)),-f $(COMPOSE_LOCAL_FILE),)
DOCKERFILE         ?= Dockerfile
DOCKER_BUILD_ARGS  ?=

MYSQL_USER          ?= homl
MYSQL_PASSWORD      ?= change_me_mysql
MYSQL_ROOT_PASSWORD ?= change_me_root
MYSQL_DATABASE      ?= homl
REDIS_PASSWORD      ?= change_me_redis

MIGRATE_DSN = mysql://$(MYSQL_USER):$(MYSQL_PASSWORD)@tcp(localhost:3306)/$(MYSQL_DATABASE)

.DEFAULT_GOAL := help

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } \
	  /^[a-zA-Z0-9_-]+:.*##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' \
	  $(MAKEFILE_LIST)

##@ Development

dev: _network ## First launch: start stack detached, migrate, seed
	docker compose $(COMPOSE_FILES) up -d --build
	@printf "Waiting for backend"
	@until nc -z localhost 8080 2>/dev/null; do printf "."; sleep 2; done && echo " ready"
	$(MAKE) migrateup
	$(MAKE) seed
	@echo "→ http://localhost:8080  (demo@homl.local / Demo1234!)"

reload: ## Rebuild and restart backend only (DB keeps running)
	docker compose $(COMPOSE_FILES) up -d --build homlback

up: _network ## Start full stack in foreground with live logs
	docker compose $(COMPOSE_FILES) up --build

down: ## Stop the compose stack
	docker compose $(COMPOSE_FILES) down --remove-orphans

local: ## Run backend process locally (requires db-up + migrateup first)
	cd src && go run .

vendor: ## Refresh vendor/ (set HTTP_PROXY/HTTPS_PROXY if needed)
	cd src && go mod tidy && go mod vendor

##@ Docker

build: ## Build backend Docker image
	docker build -f $(DOCKERFILE) $(DOCKER_BUILD_ARGS) -t $(APP_IMAGE) .

##@ Database

db-up: _network ## Start MySQL + Redis standalone (no backend)
	docker rm -f redis_container >/dev/null 2>&1 || true
	docker run --net-alias redis_container --name redis_container \
	  --net $(DOCKER_NETWORK) --rm -d -p 6379:6379 redis:alpine \
	  /bin/sh -c 'redis-server --appendonly yes --requirepass $(REDIS_PASSWORD)'
	docker rm -f mysql_container >/dev/null 2>&1 || true
	docker run --net-alias mysql_container --name mysql_container \
	  --net $(DOCKER_NETWORK) --rm -d \
	  -e MYSQL_ROOT_PASSWORD=$(MYSQL_ROOT_PASSWORD) \
	  -e MYSQL_DATABASE=$(MYSQL_DATABASE) \
	  -e MYSQL_USER=$(MYSQL_USER) \
	  -e MYSQL_PASSWORD=$(MYSQL_PASSWORD) \
	  -p 3306:3306 mysql:8.4
	@printf "Waiting for MySQL"
	@until docker exec mysql_container mysql -u$(MYSQL_USER) -p$(MYSQL_PASSWORD) \
	  -e "SELECT 1" >/dev/null 2>&1; do printf "."; sleep 2; done && echo " ready"

db-down: ## Stop MySQL + Redis containers
	docker kill mysql_container redis_container 2>/dev/null || true

migrateup: ## Apply all pending migrations
	migrate -path db/migrations -database "$(MIGRATE_DSN)" -verbose up

migratedown: ## Roll back the latest migration
	migrate -path db/migrations -database "$(MIGRATE_DSN)" -verbose down 1

migratefix: ## Force migration version (use after a failed migration)
	migrate -path db/migrations -database "$(MIGRATE_DSN)" -verbose force 1

migratecreate: ## Create a new migration file pair
	migrate create -ext sql -dir db/migrations -seq mysql

seed: ## Seed the database with demo data (idempotent)
	docker exec -i mysql_container mysql \
	  -u$(MYSQL_USER) -p$(MYSQL_PASSWORD) $(MYSQL_DATABASE) < db/seeder.sql

##@ Cleanup

clean: ## Remove stack, named volumes, orphan containers, and built images
	docker compose $(COMPOSE_FILES) down --volumes --remove-orphans --rmi local || true
	docker rm -f mysql_container redis_container >/dev/null 2>&1 || true
	docker network rm $(DOCKER_NETWORK) >/dev/null 2>&1 || true

# ---- internal ----

_network:
	@docker network create $(DOCKER_NETWORK) 2>/dev/null || true

.PHONY: help dev reload up down local vendor build \
        db-up db-down migrateup migratedown migratefix migratecreate seed \
        clean _network
