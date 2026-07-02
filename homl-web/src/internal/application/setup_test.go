package application_test

import (
	"os"
	"testing"
)

// TestMain provisions the crypto/JWT secrets required by the crypto and token
// packages for every service test in this package.
func TestMain(m *testing.M) {
	os.Setenv("ENVIRONMENT", "TEST")
	os.Setenv("ACCESS_SECRET", "test_access_secret")
	os.Setenv("REFRESH_SECRET", "test_refresh_secret")
	os.Setenv("ENCRYPT_SECRET", "01234567890123456789012345678901") // 32 bytes -> AES-256

	os.Exit(m.Run())
}
