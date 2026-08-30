FROM golang:1.26-alpine AS builder

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

FROM alpine:3.20

WORKDIR /app
COPY --from=builder /homlback /app/homlback

# Run as an unprivileged user: the service needs no root capability.
RUN adduser -D -u 10001 homl
USER homl

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget -qO- http://localhost:8080/healthz >/dev/null || exit 1

CMD ["/app/homlback"]
