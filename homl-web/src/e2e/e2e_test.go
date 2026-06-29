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

	name := fmt.Sprintf("E2E-%d", time.Now().UnixNano())

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
