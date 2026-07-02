package env

import "os"

// IsDev reports whether the service runs in the development environment.
func IsDev() bool {
	return os.Getenv("ENVIRONMENT") == "DEV"
}
