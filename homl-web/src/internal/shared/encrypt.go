package shared

import (
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"errors"
	"os"
)

var disableEncryption = false // Only for DEV
var bytes = []byte{35, 46, 57, 24, 85, 35, 24, 74, 87, 35, 88, 98, 66, 32, 14, 05}

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

// Encrypt method is to encrypt or hide any classified text
func Encrypt(text string) (string, error) {
	if disableEncryption {
		return text, nil
	}
	secret := os.Getenv("ENCRYPT_SECRET")
	block, err := aes.NewCipher([]byte(secret))
	if err != nil {
		return "", err
	}
	plainText := []byte(text)
	cfb := cipher.NewCFBEncrypter(block, bytes)
	cipherText := make([]byte, len(plainText))
	cfb.XORKeyStream(cipherText, plainText)
	return Encode(cipherText), nil
}

// Decrypt method is to extract back the encrypted text
func Decrypt(text string) (string, error) {
	if disableEncryption {
		return text, nil
	}
	secret := os.Getenv("ENCRYPT_SECRET")
	block, err := aes.NewCipher([]byte(secret))
	if err != nil {
		return "", err
	}
	cipherText, err := Decode(text)
	if err != nil {
		return "", err
	}
	cfb := cipher.NewCFBDecrypter(block, bytes)
	plainText := make([]byte, len(cipherText))
	cfb.XORKeyStream(plainText, cipherText)
	return string(plainText), nil
}

func ParsePublicKey(clientPublicKeyBase64 string) ([]byte, error) {
	clientPublicKeyBytes, err := base64.StdEncoding.DecodeString(clientPublicKeyBase64)
	if err != nil {
		return nil, errors.New("failed to decode base64")
	}

	return clientPublicKeyBytes, nil
}
