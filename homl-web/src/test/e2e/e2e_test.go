//go:build e2e

// Package e2e contains true end-to-end tests that exercise a *running* HOML
// stack (Go API + MySQL + Redis) over real HTTP.
//
// They are gated behind the `e2e` build tag so they never run as part of the
// normal `go test ./...` (which must stay fast and dependency-free).
//
// Run them against a live stack:
//
//	cd homl-web && make dev        # boots the stack + seeds the demo user
//	make test-e2e                  # or: go test -tags e2e ./e2e/...
//
// Configure the target / credentials via env vars (defaults match `make dev`):
//
//	E2E_BASE_URL   (default http://localhost:8080/api)
//	E2E_USERNAME   (default demo@homl.local)
//	E2E_PASSWORD   (default Demo1234!)
package e2e

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"testing"
	"time"
)

func baseURL() string  { return env("E2E_BASE_URL", "http://localhost:8080/api") }
func username() string { return env("E2E_USERNAME", "demo@homl.local") }
func password() string { return env("E2E_PASSWORD", "Demo1234!") }

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

type client struct {
	t     *testing.T
	http  *http.Client
	token string
}

func newClient(t *testing.T) *client {
	return &client{t: t, http: &http.Client{Timeout: 10 * time.Second}}
}

// do performs a request and returns the status code and raw body. A non-empty
// token is sent as a Bearer Authorization header.
func (c *client) do(method, path string, body interface{}) (int, []byte) {
	c.t.Helper()

	var reader io.Reader
	if body != nil {
		buf, err := json.Marshal(body)
		if err != nil {
			c.t.Fatalf("marshal body: %v", err)
		}
		reader = bytes.NewReader(buf)
	}

	req, err := http.NewRequest(method, baseURL()+path, reader)
	if err != nil {
		c.t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	if c.token != "" {
		req.Header.Set("Authorization", "Bearer "+c.token)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		c.t.Fatalf("%s %s: request failed (is the stack up? `make dev`): %v", method, path, err)
	}
	defer resp.Body.Close()

	out, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, out
}

func (c *client) login() {
	c.t.Helper()
	status, body := c.do(http.MethodPost, "/login", map[string]string{
		"username": username(),
		"password": password(),
	})
	if status != http.StatusOK {
		c.t.Fatalf("login failed: status %d, body %s", status, body)
	}
	var tokens map[string]string
	if err := json.Unmarshal(body, &tokens); err != nil {
		c.t.Fatalf("decode login body: %v", err)
	}
	if tokens["access_token"] == "" || tokens["refresh_token"] == "" {
		c.t.Fatalf("login response missing tokens: %s", body)
	}
	c.token = tokens["access_token"]
}

// Auth checks: login returns tokens, a protected route is reachable with the token
// and rejected without it, then logout invalidates the session.
func TestAuthFlow(t *testing.T) {
	c := newClient(t)
	c.login()

	// Protected route reachable with the token.
	status, body := c.do(http.MethodGet, "/categories", nil)
	if status != http.StatusOK {
		t.Fatalf("GET /categories with token: status %d, body %s", status, body)
	}

	// Without a token it must be rejected.
	noAuth := newClient(t)
	if status, _ := noAuth.do(http.MethodGet, "/categories", nil); status != http.StatusUnauthorized {
		t.Fatalf("GET /categories without token: expected 401, got %d", status)
	}

	// Logout invalidates the session.
	if status, body := c.do(http.MethodPost, "/logout", nil); status != http.StatusNoContent {
		t.Fatalf("POST /logout: status %d, body %s", status, body)
	}
}

type categoryResponse struct {
	Id       uint   `json:"id"`
	Category string `json:"category"`
	Color    string `json:"color"`
	IsLocked bool   `json:"isLocked"`
}

// TestCategoryLifecycle creates a category, verifies it shows up in the list,
// then deletes it — a self-cleaning CRUD round-trip against the real DB.
func TestCategoryLifecycle(t *testing.T) {
	c := newClient(t)
	c.login()

	// CreateCategory title-cases what it stores, so "E2E-1" would come back
	// as "E2e-1" and never match. This form is already title-cased and
	// survives the normalization unchanged — do not "fix" the casing.
	name := fmt.Sprintf("E2e-%d", time.Now().UnixNano())

	if status, body := c.do(http.MethodPost, "/categories", map[string]string{
		"category": name,
		"color":    "#abcdef",
	}); status != http.StatusCreated {
		t.Fatalf("create category: status %d, body %s", status, body)
	}

	created := findCategory(t, c, name)
	if created == nil {
		t.Fatalf("created category %q not found in GET /categories", name)
	}

	if status, body := c.do(http.MethodDelete, fmt.Sprintf("/categories/%d", created.Id),
		map[string]bool{"moveTags": false}); status != http.StatusNoContent {
		t.Fatalf("delete category: status %d, body %s", status, body)
	}

	if findCategory(t, c, name) != nil {
		t.Fatalf("category %q still present after delete", name)
	}
}

func findCategory(t *testing.T, c *client, name string) *categoryResponse {
	t.Helper()
	status, body := c.do(http.MethodGet, "/categories", nil)
	if status != http.StatusOK {
		t.Fatalf("GET /categories: status %d, body %s", status, body)
	}
	var categories []categoryResponse
	if err := json.Unmarshal(body, &categories); err != nil {
		t.Fatalf("decode categories: %v", err)
	}
	for i := range categories {
		if categories[i].Category == name {
			return &categories[i]
		}
	}
	return nil
}

// register creates a throwaway account and authenticates the client as it.
// Account deletion must never run against the shared seeded demo user, which
// the rest of the suite (and the next run) depends on.
func (c *client) register(email, pass string) {
	c.t.Helper()
	status, body := c.do(http.MethodPost, "/registration", map[string]string{
		"username": email,
		"password": pass,
		"language": "en",
	})
	if status != http.StatusOK && status != http.StatusCreated {
		c.t.Fatalf("registration failed: status %d, body %s", status, body)
	}
	var tokens map[string]string
	if err := json.Unmarshal(body, &tokens); err != nil {
		c.t.Fatalf("decode registration body: %v", err)
	}
	if tokens["access_token"] == "" {
		c.t.Fatalf("registration response missing tokens: %s", body)
	}
	c.token = tokens["access_token"]
}

// TestAccountDeletion walks the whole "delete my account" flow on a throwaway
// account: the wrong password is refused, the right one erases the account,
// and neither the old session nor the credentials work afterwards.
//
// It adds one registration and one login to the per-IP /login budget
// (10/min), which the rest of the suite leaves room for.
func TestAccountDeletion(t *testing.T) {
	email := fmt.Sprintf("e2e-delete-%d@homl.local", time.Now().UnixNano())
	const pass = "Delete1234!"

	c := newClient(t)
	c.register(email, pass)

	// Own some data, so the cascade has something to sweep.
	status, body := c.do(http.MethodPost, "/categories", map[string]string{
		"category": "Trips",
		"color":    "#ffff60",
	})
	if status != http.StatusCreated && status != http.StatusOK {
		t.Fatalf("POST /categories: status %d, body %s", status, body)
	}

	// A wrong password must not delete anything.
	if status, body := c.do(http.MethodDelete, "/account", map[string]string{"password": "WrongPass123!"}); status != http.StatusUnauthorized {
		t.Fatalf("DELETE /account with a wrong password: expected 401, got %d, body %s", status, body)
	}
	if status, body := c.do(http.MethodGet, "/categories", nil); status != http.StatusOK {
		t.Fatalf("GET /categories after the refused deletion: status %d, body %s", status, body)
	}

	// The right password erases the account.
	if status, body := c.do(http.MethodDelete, "/account", map[string]string{"password": pass}); status != http.StatusNoContent {
		t.Fatalf("DELETE /account: status %d, body %s", status, body)
	}

	// The session died with the account.
	if status, _ := c.do(http.MethodGet, "/categories", nil); status != http.StatusUnauthorized {
		t.Fatalf("GET /categories with the token of a deleted account: expected 401, got %d", status)
	}

	// And so did the credentials.
	fresh := newClient(t)
	if status, _ := fresh.do(http.MethodPost, "/login", map[string]string{"username": email, "password": pass}); status != http.StatusUnauthorized {
		t.Fatalf("POST /login with deleted credentials: expected 401, got %d", status)
	}
}
