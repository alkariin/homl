package crypto

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

var testAES = NewAES("01234567890123456789012345678901") // 32 bytes -> AES-256

func TestEncryptDecryptRoundTrip(t *testing.T) {
	cases := []string{"Cinema", "Vacances d'été", "", "123456", "noël 🎄"}

	for _, plain := range cases {
		t.Run(plain, func(t *testing.T) {
			encrypted, err := testAES.Encrypt(plain)
			assert.NoError(t, err)

			decrypted, err := testAES.Decrypt(encrypted)
			assert.NoError(t, err)
			assert.Equal(t, plain, decrypted)
		})
	}
}

func TestEncryptIsDeterministic(t *testing.T) {
	// The cipher uses a fixed IV, so the same plaintext always yields the same
	// ciphertext. The service layer relies on this to look tags up by value.
	a, err := testAES.Encrypt("December")
	assert.NoError(t, err)
	b, err := testAES.Encrypt("December")
	assert.NoError(t, err)
	assert.Equal(t, a, b)

	other, err := testAES.Encrypt("November")
	assert.NoError(t, err)
	assert.NotEqual(t, a, other)
}

func TestEncodeDecodeRoundTrip(t *testing.T) {
	raw := []byte{0x00, 0x10, 0x42, 0xff}
	decoded, err := Decode(Encode(raw))
	assert.NoError(t, err)
	assert.Equal(t, raw, decoded)
}
