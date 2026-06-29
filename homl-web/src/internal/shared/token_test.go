package shared

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestCreateToken(t *testing.T) {
	td, err := CreateToken(42)

	assert.NoError(t, err)
	assert.NotEmpty(t, td.AccessToken)
	assert.NotEmpty(t, td.RefreshToken)
	assert.NotEmpty(t, td.AccessUuid)
	assert.NotEmpty(t, td.RefreshUuid)
}

func TestExtractTokenMetadata(t *testing.T) {
	td, err := CreateToken(42)
	assert.NoError(t, err)

	req, _ := http.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer "+td.AccessToken)

	ad, err := ExtractTokenMetadata(req)

	assert.NoError(t, err)
	assert.Equal(t, uint64(42), ad.UserId)
	assert.Equal(t, td.AccessUuid, ad.AccessUuid)
}

func TestExtractTokenMetadataRejectsGarbage(t *testing.T) {
	req, _ := http.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer not-a-real-jwt")

	ad, err := ExtractTokenMetadata(req)

	assert.Error(t, err)
	assert.Nil(t, ad)
}

func TestVerifyTokenAndRefresh(t *testing.T) {
	td, err := CreateToken(7)
	assert.NoError(t, err)

	claims, ok := VerifyTokenAndRefresh(td.RefreshToken)
	assert.True(t, ok)
	assert.Equal(t, td.RefreshUuid, claims["refresh_uuid"])

	_, ok = VerifyTokenAndRefresh("bogus")
	assert.False(t, ok)
}
