FROM golang:1.23-alpine AS builder

WORKDIR /app

RUN apk add --no-cache ca-certificates

# Cache deps first for reproducible and faster builds
COPY ./src/go.mod ./src/go.sum ./
RUN go mod download

COPY ./src/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -o /homlback .

FROM alpine:3.20

WORKDIR /app
COPY --from=builder /homlback /app/homlback

EXPOSE 8080

CMD ["/app/homlback"]
