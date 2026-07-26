package e2ee

import (
	"context"
	"encoding/base64"
	"strings"
	"testing"
)

// validBlob returns a well-formed client payload of n decoded bytes.
func validBlob(n int) string {
	return Prefix + base64.StdEncoding.EncodeToString(make([]byte, n))
}

func TestIsBlob(t *testing.T) {
	cases := []struct {
		name  string
		value string
		want  bool
	}{
		{"minimal blob (nonce + tag only)", validBlob(28), true},
		{"regular blob", validBlob(60), true},
		{"missing prefix", base64.StdEncoding.EncodeToString(make([]byte, 60)), false},
		{"wrong version", "e2ee:v2:" + base64.StdEncoding.EncodeToString(make([]byte, 60)), false},
		{"payload too short", validBlob(27), false},
		{"invalid base64", Prefix + "not-base64!!", false},
		{"empty", "", false},
		{"prefix only", Prefix, false},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := IsBlob(c.value); got != c.want {
				t.Errorf("IsBlob(%q) = %v, want %v", c.value, got, c.want)
			}
		})
	}
}

func TestIsIndex(t *testing.T) {
	valid := strings.Repeat("0a", 16)
	cases := []struct {
		name  string
		value string
		want  bool
	}{
		{"valid index", valid, true},
		{"too short", valid[:30], false},
		{"too long", valid + "aa", false},
		{"uppercase hex", strings.ToUpper(valid), false},
		{"non-hex rune", valid[:31] + "g", false},
		{"empty", "", false},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := IsIndex(c.value); got != c.want {
				t.Errorf("IsIndex(%q) = %v, want %v", c.value, got, c.want)
			}
		})
	}
}

func TestIsKeyCheck(t *testing.T) {
	valid := strings.Repeat("0f", 32)
	if !IsKeyCheck(valid) {
		t.Errorf("IsKeyCheck rejects a valid value")
	}
	if IsKeyCheck(valid[:62]) || IsKeyCheck(valid+"00") || IsKeyCheck(strings.ToUpper(valid)) {
		t.Errorf("IsKeyCheck accepts a malformed value")
	}
}

func TestContextFlag(t *testing.T) {
	ctx := context.Background()
	if Enabled(ctx) {
		t.Errorf("Enabled must default to false")
	}
	if !Enabled(WithEnabled(ctx, true)) {
		t.Errorf("Enabled must report the stored flag")
	}
	if Enabled(WithEnabled(ctx, false)) {
		t.Errorf("Enabled must report the stored flag")
	}
}
