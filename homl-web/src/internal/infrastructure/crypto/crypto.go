// Package crypto is the infrastructure adapter for at-rest field encryption.
// It implements the application.Encryptor port.
package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hkdf"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"strconv"
	"sync"
)

// nonceSize is the AES-GCM standard nonce length (96 bits).
const nonceSize = 12

// Keyring derives one encryption key set per user from the master secret via
// HKDF-SHA256, so identical plaintexts stored by different users never share a
// ciphertext. The encryption itself is deterministic authenticated encryption
// (a synthetic-IV / SIV construction): the nonce is derived from the plaintext
// with a keyed HMAC, so the same plaintext of the same user always yields the
// same ciphertext (the services rely on this to look encrypted values up by
// equality), while AES-GCM authenticates the ciphertext (tampering is detected
// on decrypt). Because the nonce depends on a secret key, distinct plaintexts
// get unpredictable, non-repeating nonces.
type Keyring struct {
	secret []byte

	mu    sync.RWMutex
	cache map[uint64]*userKeys // derived keys, one entry per user
}

type userKeys struct {
	encKey []byte // AES-256 key
	macKey []byte // key for the nonce-deriving HMAC
}

func NewKeyring(secret string) *Keyring {
	return &Keyring{
		secret: []byte(secret),
		cache:  make(map[uint64]*userKeys),
	}
}

// keysFor returns the derived key set of a user, deriving and caching it on
// first use.
func (k *Keyring) keysFor(idUser uint64) (*userKeys, error) {
	k.mu.RLock()
	keys, ok := k.cache[idUser]
	k.mu.RUnlock()
	if ok {
		return keys, nil
	}

	// 64 bytes: the first half encrypts, the second half keys the nonce HMAC.
	// The user id in the info string domain-separates the users.
	material, err := hkdf.Key(sha256.New, k.secret, nil, "homl-user-key:v1:"+strconv.FormatUint(idUser, 10), 64)
	if err != nil {
		return nil, err
	}
	keys = &userKeys{encKey: material[:32], macKey: material[32:]}

	k.mu.Lock()
	k.cache[idUser] = keys
	k.mu.Unlock()
	return keys, nil
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

func (u *userKeys) gcm() (cipher.AEAD, error) {
	block, err := aes.NewCipher(u.encKey)
	if err != nil {
		return nil, err
	}
	return cipher.NewGCM(block)
}

// deriveNonce computes a deterministic 12-byte nonce from the plaintext, keyed
// with macKey so it cannot be predicted without the secret.
func (u *userKeys) deriveNonce(plainText []byte) []byte {
	mac := hmac.New(sha256.New, u.macKey)
	mac.Write(plainText)
	return mac.Sum(nil)[:nonceSize]
}

// Encrypt returns base64(nonce || ciphertext+tag) under the user's derived
// key. It is deterministic (per user) and authenticated.
func (k *Keyring) Encrypt(text string, idUser uint64) (string, error) {
	keys, err := k.keysFor(idUser)
	if err != nil {
		return "", err
	}
	gcm, err := keys.gcm()
	if err != nil {
		return "", err
	}
	plainText := []byte(text)
	nonce := keys.deriveNonce(plainText)
	cipherText := gcm.Seal(nonce, nonce, plainText, nil)
	return Encode(cipherText), nil
}

// Decrypt reverses Encrypt. It returns an error if the input is malformed or if
// the authentication tag does not verify (tampered ciphertext or wrong user).
func (k *Keyring) Decrypt(text string, idUser uint64) (string, error) {
	keys, err := k.keysFor(idUser)
	if err != nil {
		return "", err
	}
	gcm, err := keys.gcm()
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
