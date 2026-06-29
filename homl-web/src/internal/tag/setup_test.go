package tag

import (
	"os"
	"testing"
)

// TestMain provisions the crypto secrets and drops a copy of constants.json
// next to the test binary, because the tags service reads it from the current
// working directory via shared.GetConstants.
func TestMain(m *testing.M) {
	os.Setenv("ENVIRONMENT", "TEST")
	os.Setenv("ACCESS_SECRET", "test_access_secret")
	os.Setenv("REFRESH_SECRET", "test_refresh_secret")
	os.Setenv("ENCRYPT_SECRET", "01234567890123456789012345678901") // 32 bytes -> AES-256

	if constants, err := os.ReadFile("../../constants.json"); err == nil {
		_ = os.WriteFile("constants.json", constants, 0o644)
	}

	code := m.Run()

	os.Remove("constants.json")
	os.Exit(code)
}
