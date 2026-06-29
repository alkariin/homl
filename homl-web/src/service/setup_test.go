package service

import (
	"os"
	"testing"
)

// TestMain sets up the environment shared by every test in the service package.
//
//   - The crypto secrets are required by helper.Encrypt/Decrypt and helper.CreateToken.
//     ENCRYPT_SECRET must be a valid AES key length (16, 24 or 32 bytes); we use 32.
//   - The tags service reads "constants.json" from the current working directory
//     (helper.GetConstants), so we drop a copy next to the test binary and remove
//     it on teardown.
func TestMain(m *testing.M) {
	os.Setenv("ENVIRONMENT", "TEST")
	os.Setenv("ACCESS_SECRET", "test_access_secret")
	os.Setenv("REFRESH_SECRET", "test_refresh_secret")
	os.Setenv("ENCRYPT_SECRET", "01234567890123456789012345678901") // 32 bytes -> AES-256

	constants, err := os.ReadFile("../constants.json")
	if err == nil {
		_ = os.WriteFile("constants.json", constants, 0o644)
		defer os.Remove("constants.json")
	}

	code := m.Run()

	// defer above doesn't run on os.Exit, so clean up explicitly.
	os.Remove("constants.json")
	os.Exit(code)
}
