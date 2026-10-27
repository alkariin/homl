FROM golang:1.27-alpine AS builder

WORKDIR /app

RUN apk add --no-cache ca-certificates

# Cache deps first for reproducible and faster builds
COPY ./src/go.mod ./src/go.sum ./
RUN go mod download

COPY ./src/ ./
# VERSION is what /healthz and the startup log report; the Makefile passes
# `git describe` (the .git directory is outside the build context).
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build \
  -ldflags "-X github.com/alkariin/homl/homl-web/internal/version.Version=${VERSION}" \
  -o /homlback .

FROM alpine:3.24

WORKDIR /app
COPY --from=builder /homlback /app/homlback

# The schema migrations of this very version, with golang-migrate and
# /app/migrate to apply them: a server running the published image upgrades
# without a checkout (docs/deployment.md §3).
COPY --from=migrate/migrate:v4.20.1 /usr/local/bin/migrate /usr/local/bin/migrate
COPY ./db/migrations /app/migrations
COPY ./scripts/migrate-in-image.sh /app/migrate

# Run as an unprivileged user: the service needs no root capability.
RUN adduser -D -u 10001 homl && chmod 755 /app/migrate
USER homl

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget -qO- http://localhost:8080/healthz >/dev/null || exit 1

CMD ["/app/homlback"]
