package application

import "github.com/alkariin/homl/homl-web/internal/domain/user"

// Encryptor is the application-side port for at-rest field encryption.
// Implemented by infrastructure/crypto.
type Encryptor interface {
	Encrypt(text string) (string, error)
	Decrypt(text string) (string, error)
}

// TokenIssuer is the application-side port for minting and verifying auth
// token pairs. Implemented by infrastructure/auth.
type TokenIssuer interface {
	CreateToken(userid uint64) (*user.TokenDetails, error)
	VerifyRefresh(refreshToken string) (*user.RefreshDetails, error)
}
