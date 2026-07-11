package application

import "github.com/alkariin/homl/homl-web/internal/domain/user"

// Encryptor is the application-side port for at-rest field encryption. Keys
// are derived per user, so identical plaintexts of different users never
// share a ciphertext. Implemented by infrastructure/crypto.
type Encryptor interface {
	Encrypt(text string, idUser uint64) (string, error)
	Decrypt(text string, idUser uint64) (string, error)
}

// TokenIssuer is the application-side port for minting and verifying auth
// token pairs. Implemented by infrastructure/auth.
type TokenIssuer interface {
	CreateToken(userid uint64) (*user.TokenDetails, error)
	VerifyRefresh(refreshToken string) (*user.RefreshDetails, error)
}

// Mailer is the application-side port for outgoing transactional emails.
// Implemented by infrastructure/mail.
type Mailer interface {
	SendPasswordResetCode(to string, code string) error
}
