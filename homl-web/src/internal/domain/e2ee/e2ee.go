// Package e2ee holds the cross-cutting pieces of the opt-in end-to-end
// encryption feature: the client payload format, the per-request mode flag
// and the migration persistence port. See docs/e2ee.md.
package e2ee

import (
	"context"
	"encoding/base64"
	"strings"
)

// Prefix marks a client-encrypted value: AES-256-GCM under a device-held key,
// serialized as base64(nonce || ciphertext || tag). The version segment lets
// future formats coexist with stored values.
const Prefix = "e2ee:v1:"

// minBlobBytes is the smallest possible decoded payload: a 12-byte GCM nonce
// followed by a 16-byte authentication tag (empty plaintext).
const minBlobBytes = 28

// IsBlob reports whether s is a well-formed client-encrypted value. The
// server cannot (and must not) verify more than the shape.
func IsBlob(s string) bool {
	rest, ok := strings.CutPrefix(s, Prefix)
	if !ok {
		return false
	}
	raw, err := base64.StdEncoding.DecodeString(rest)
	return err == nil && len(raw) >= minBlobBytes
}

// IsIndex reports whether s is a well-formed blind index: the first 16 bytes
// of an HMAC-SHA256 in lowercase hex.
func IsIndex(s string) bool { return isLowerHex(s, 32) }

// IsKeyCheck reports whether s is a well-formed key-check value: a full
// HMAC-SHA256 in lowercase hex.
func IsKeyCheck(s string) bool { return isLowerHex(s, 64) }

func isLowerHex(s string, length int) bool {
	if len(s) != length {
		return false
	}
	for _, r := range s {
		if (r < '0' || r > '9') && (r < 'a' || r > 'f') {
			return false
		}
	}
	return true
}

// ctxKey scopes the per-request flag stored by WithEnabled.
type ctxKey struct{}

// WithEnabled returns a context carrying the authenticated user's E2EE flag.
// It is set once per request by the web layer so the application and
// persistence layers can branch without re-querying the user row.
func WithEnabled(ctx context.Context, enabled bool) context.Context {
	return context.WithValue(ctx, ctxKey{}, enabled)
}

// Enabled reports the flag stored by WithEnabled (false when absent).
func Enabled(ctx context.Context) bool {
	enabled, _ := ctx.Value(ctxKey{}).(bool)
	return enabled
}

// MigrationCategory carries one category value through POST /e2ee/migrate:
// an E2EE blob on enable, plaintext on disable.
type MigrationCategory struct {
	Id       uint   `json:"id"`
	Category string `json:"category"`
}

// MigrationTag carries one tag value through POST /e2ee/migrate. TagIndex is
// required on enable and ignored on disable (the column is cleared).
type MigrationTag struct {
	Id       uint    `json:"id"`
	Tag      string  `json:"tag"`
	TagIndex *string `json:"tagIndex"`
}

// MigrationEvent carries one event description through POST /e2ee/migrate.
type MigrationEvent struct {
	Id          uint   `json:"id"`
	Description string `json:"description"`
}

// MigrationData is the user's whole dataset re-encrypted by the client. The
// id sets must exactly match the rows stored server-side.
type MigrationData struct {
	Categories []MigrationCategory `json:"categories"`
	Tags       []MigrationTag      `json:"tags"`
	Events     []MigrationEvent    `json:"events"`
}

// Repository is the persistence port of the E2EE feature.
type Repository interface {
	// IsEnabled reports the user's persisted E2EE flag.
	IsEnabled(ctx context.Context, idUser uint64) (bool, error)
	// Migrate atomically replaces every encrypted value of the user with the
	// given data and flips the flag; keyCheck is stored on enable and cleared
	// on disable. On disable the values arrive as plaintext and are encrypted
	// with the at-rest scheme inside the transaction. It conflicts when the
	// flag already matches the requested direction or when the payload id
	// sets do not match the stored rows (the client must refetch and retry).
	Migrate(ctx context.Context, idUser uint64, enable bool, keyCheck *string, data *MigrationData) error
	// Purge deletes every event, tag and category of the user, reseeds the
	// default categories and clears the E2EE flag. Last resort when the key
	// is lost: the account survives, the data does not.
	Purge(ctx context.Context, idUser uint64) error
}
