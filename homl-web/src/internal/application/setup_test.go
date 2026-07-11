package application_test

import (
	"github.com/alkariin/homl/homl-web/internal/infrastructure/auth"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/crypto"
)

// Real infrastructure adapters wired into the services under test: the
// service tests assert on real ciphertexts and real JWTs, only the
// repositories are mocked.
var (
	testCrypto = crypto.NewKeyring("01234567890123456789012345678901")
	testTokens = auth.NewJWT("test_access_secret", "test_refresh_secret", false)
)
