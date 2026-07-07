// Package crypto is the infrastructure adapter for at-rest field encryption.
// It implements the application.Encryptor port.
package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"errors"
)

// nonceSize is the AES-GCM standard nonce length (96 bits).
const nonceSize = 12

// AES provides deterministic authenticated encryption (a synthetic-IV / SIV
// construction). The nonce is derived from the plaintext with a keyed HMAC, so
// the same plaintext always yields the same ciphertext (the services rely on
// this to look encrypted values up by equality), while AES-GCM authenticates
// the ciphertext (tampering is detected on decrypt). Because the nonce depends
// on a secret key, distinct plaintexts get unpredictable, non-repeating nonces,
// which removes the keystream reuse of the former fixed-IV CFB scheme.
type AES struct {
	encKey []byte // AES-256 key
	macKey []byte // key for the nonce-deriving HMAC
}

// NewAES derives the encryption and nonce keys from secret via domain-separated
// SHA-256, so any non-empty secret length is accepted (the raw secret no longer
// has to be exactly 16/24/32 bytes).
func NewAES(secret string) *AES {
	encKey := sha256.Sum256([]byte("homl-enc-v1:" + secret))
	macKey := sha256.Sum256([]byte("homl-mac-v1:" + secret))
	return &AES{encKey: encKey[:], macKey: macKey[:]}
}

func Encode(b []byte) string {
	return base64.StdEncoding.EncodeToString(b)
}

func Decode(s string) ([]byte, error) {
	data, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		return nil, err
	}
	return data, nil
}

func (a *AES) gcm() (cipher.AEAD, error) {
	block, err := aes.NewCipher(a.encKey)
	if err != nil {
		return nil, err
	}
	return cipher.NewGCM(block)
}

// deriveNonce computes a deterministic 12-byte nonce from the plaintext, keyed
// with macKey so it cannot be predicted without the secret.
func (a *AES) deriveNonce(plainText []byte) []byte {
	mac := hmac.New(sha256.New, a.macKey)
	mac.Write(plainText)
	return mac.Sum(nil)[:nonceSize]
}

// Encrypt returns base64(nonce || ciphertext+tag). It is deterministic and
// authenticated.
func (a *AES) Encrypt(text string) (string, error) {
	gcm, err := a.gcm()
	if err != nil {
		return "", err
	}
	plainText := []byte(text)
	nonce := a.deriveNonce(plainText)
	cipherText := gcm.Seal(nonce, nonce, plainText, nil)
	return Encode(cipherText), nil
}

// Decrypt reverses Encrypt. It returns an error if the input is malformed or if
// the authentication tag does not verify (tampered ciphertext).
func (a *AES) Decrypt(text string) (string, error) {
	gcm, err := a.gcm()
	if err != nil {
		return "", err
	}
	raw, err := Decode(text)
	if err != nil {
		return "", err
	}
	if len(raw) < nonceSize {
		return "", errors.New("ciphertext too short")
	}
	nonce, cipherText := raw[:nonceSize], raw[nonceSize:]
	plainText, err := gcm.Open(nil, nonce, cipherText, nil)
	if err != nil {
		return "", err
	}
	return string(plainText), nil
}
