package crypto

import (
	"os"
	"testing"
)

func TestMain(m *testing.M) {
	os.Setenv("ENVIRONMENT", "TEST")
	os.Setenv("ENCRYPT_SECRET", "01234567890123456789012345678901") // 32 bytes -> AES-256

	os.Exit(m.Run())
}
