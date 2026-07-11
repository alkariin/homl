package crypto

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

var testKeyring = NewKeyring("01234567890123456789012345678901")

func TestEncryptDecryptRoundTrip(t *testing.T) {
	cases := []string{"Cinema", "Vacances d'été", "", "123456", "noël 🎄"}

	for _, plain := range cases {
		t.Run(plain, func(t *testing.T) {
			encrypted, err := testKeyring.Encrypt(plain, 1)
			assert.NoError(t, err)

			decrypted, err := testKeyring.Decrypt(encrypted, 1)
			assert.NoError(t, err)
			assert.Equal(t, plain, decrypted)
		})
	}
}

func TestEncryptIsDeterministicPerUser(t *testing.T) {
	// The synthetic-IV scheme derives the nonce from the plaintext, so the same
	// plaintext always yields the same ciphertext for the same user. The
	// service layer relies on this to look tags up by value.
	a, err := testKeyring.Encrypt("December", 1)
	assert.NoError(t, err)
	b, err := testKeyring.Encrypt("December", 1)
	assert.NoError(t, err)
	assert.Equal(t, a, b)

	other, err := testKeyring.Encrypt("November", 1)
	assert.NoError(t, err)
	assert.NotEqual(t, a, other)
}

func TestUsersDoNotShareCiphertexts(t *testing.T) {
	// Keys are HKDF-derived per user: the same plaintext must encrypt
	// differently across users, and one user's key must not decrypt another
	// user's ciphertext (otherwise equal values would leak across accounts).
	a, err := testKeyring.Encrypt("December", 1)
	assert.NoError(t, err)
	b, err := testKeyring.Encrypt("December", 2)
	assert.NoError(t, err)
	assert.NotEqual(t, a, b)

	_, err = testKeyring.Decrypt(a, 2)
	assert.Error(t, err)
}

func TestDecryptRejectsTamperedCiphertext(t *testing.T) {
	// AES-GCM authenticates the ciphertext: flipping a single byte must make
	// decryption fail instead of returning altered plaintext (the former CFB
	// scheme was malleable and silently accepted this).
	encrypted, err := testKeyring.Encrypt("Cinema", 1)
	assert.NoError(t, err)

	raw, err := Decode(encrypted)
	assert.NoError(t, err)
	raw[len(raw)-1] ^= 0xff // flip the last byte of the auth tag

	_, err = testKeyring.Decrypt(Encode(raw), 1)
	assert.Error(t, err)
}

func TestDecryptRejectsTooShortInput(t *testing.T) {
	_, err := testKeyring.Decrypt(Encode([]byte{0x00, 0x01}), 1)
	assert.Error(t, err)
}

func TestEncodeDecodeRoundTrip(t *testing.T) {
	raw := []byte{0x00, 0x10, 0x42, 0xff}
	decoded, err := Decode(Encode(raw))
	assert.NoError(t, err)
	assert.Equal(t, raw, decoded)
}
