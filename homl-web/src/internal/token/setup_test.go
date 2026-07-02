package token

import (
	"os"
	"testing"
)

func TestMain(m *testing.M) {
	os.Setenv("ENVIRONMENT", "TEST")
	os.Setenv("ACCESS_SECRET", "test_access_secret")
	os.Setenv("REFRESH_SECRET", "test_refresh_secret")

	os.Exit(m.Run())
}
