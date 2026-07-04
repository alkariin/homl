package auth

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

var testJWT = NewJWT("test_access_secret", "test_refresh_secret", false)

func TestCreateToken(t *testing.T) {
	td, err := testJWT.CreateToken(42)

	assert.NoError(t, err)
	assert.NotEmpty(t, td.AccessToken)
	assert.NotEmpty(t, td.RefreshToken)
	assert.NotEmpty(t, td.AccessUuid)
	assert.NotEmpty(t, td.RefreshUuid)
}

func TestExtractAccessDetails(t *testing.T) {
	td, err := testJWT.CreateToken(42)
	assert.NoError(t, err)

	req, _ := http.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer "+td.AccessToken)

	ad, err := testJWT.ExtractAccessDetails(req)

	assert.NoError(t, err)
	assert.Equal(t, uint64(42), ad.UserId)
	assert.Equal(t, td.AccessUuid, ad.AccessUuid)
}

func TestExtractAccessDetailsRejectsGarbage(t *testing.T) {
	req, _ := http.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer not-a-real-jwt")

	ad, err := testJWT.ExtractAccessDetails(req)

	assert.Error(t, err)
	assert.Nil(t, ad)
}

func TestVerifyRefresh(t *testing.T) {
	td, err := testJWT.CreateToken(7)
	assert.NoError(t, err)

	rd, err := testJWT.VerifyRefresh(td.RefreshToken)
	assert.NoError(t, err)
	assert.Equal(t, td.RefreshUuid, rd.RefreshUuid)
	assert.Equal(t, uint64(7), rd.UserId)

	_, err = testJWT.VerifyRefresh("bogus")
	assert.Error(t, err)
}
