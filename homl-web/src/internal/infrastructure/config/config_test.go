package config

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

// validSecret is 32 chars, has no "change_me" placeholder.
var validSecret = strings.Repeat("a", 32)

// baseConfig returns a config that passes validation, which each test then
// mutates to exercise one failure mode.
func baseConfig() *Config {
	return &Config{
		Environment:   "PROD",
		AccessSecret:  validSecret,
		RefreshSecret: validSecret,
		EncryptSecret: validSecret,
		CorsOrigin:    "https://app.homl.ch",
	}
}

func TestValidate(t *testing.T) {
	t.Run("accepts a fully configured prod config", func(t *testing.T) {
		assert.NoError(t, baseConfig().validate())
	})

	t.Run("rejects an empty secret", func(t *testing.T) {
		c := baseConfig()
		c.AccessSecret = ""
		assert.Error(t, c.validate())
	})

	t.Run("rejects a change_me placeholder secret", func(t *testing.T) {
		c := baseConfig()
		c.RefreshSecret = "change_me_refresh_secret"
		assert.Error(t, c.validate())
	})

	t.Run("rejects a too-short secret", func(t *testing.T) {
		c := baseConfig()
		c.EncryptSecret = strings.Repeat("a", minSecretLength-1)
		assert.Error(t, c.validate())
	})

	t.Run("rejects an empty CORS origin outside DEV", func(t *testing.T) {
		c := baseConfig()
		c.CorsOrigin = ""
		assert.Error(t, c.validate())
	})

	t.Run("rejects a wildcard CORS origin outside DEV", func(t *testing.T) {
		c := baseConfig()
		c.CorsOrigin = "*"
		assert.Error(t, c.validate())
	})

	t.Run("allows an empty CORS origin in DEV", func(t *testing.T) {
		c := baseConfig()
		c.Environment = "DEV"
		c.CorsOrigin = ""
		assert.NoError(t, c.validate())
	})

	t.Run("still enforces secrets in DEV", func(t *testing.T) {
		c := baseConfig()
		c.Environment = "DEV"
		c.CorsOrigin = ""
		c.AccessSecret = ""
		assert.Error(t, c.validate())
	})
}

func TestParseBool(t *testing.T) {
	t.Run("unset falls back", func(t *testing.T) {
		for _, value := range []string{"", "  "} {
			open, err := parseBool("REGISTRATION_OPEN", value, true)
			assert.NoError(t, err)
			assert.True(t, open)
		}
	})

	t.Run("reads the strconv spellings", func(t *testing.T) {
		for value, want := range map[string]bool{
			"true": true, "TRUE": true, "1": true,
			"false": false, "False": false, "0": false, " false ": false,
		} {
			got, err := parseBool("REGISTRATION_OPEN", value, true)
			assert.NoError(t, err, value)
			assert.Equal(t, want, got, value)
		}
	})

	t.Run("refuses anything else rather than guess", func(t *testing.T) {
		for _, value := range []string{"no", "off", "closed", "flase"} {
			_, err := parseBool("REGISTRATION_OPEN", value, true)
			assert.ErrorContains(t, err, "REGISTRATION_OPEN", value)
		}
	})
}

func TestSplitList(t *testing.T) {
	assert.Equal(t, []string{"10.0.0.0/8", "172.18.0.5"}, splitList(" 10.0.0.0/8 , 172.18.0.5 ,"))
	assert.Nil(t, splitList("  "))
}

func TestValidateTrustedProxies(t *testing.T) {
	t.Run("accepts IPs and CIDRs", func(t *testing.T) {
		c := baseConfig()
		c.TrustedProxies = []string{"10.0.0.0/8", "172.18.0.5", "::1"}

		assert.NoError(t, c.validate())
	})

	// A typo would otherwise reach gin and panic the whole service at
	// startup, so it has to be rejected with a readable message instead.
	t.Run("rejects anything else", func(t *testing.T) {
		c := baseConfig()
		c.TrustedProxies = []string{"nginx"}

		err := c.validate()

		assert.ErrorContains(t, err, "TRUSTED_PROXIES")
	})
}
