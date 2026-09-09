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
	Kind     string `json:"kind"`
	Tags     []struct {
		Id  uint   `json:"id"`
		Tag string `json:"tag"`
	} `json:"tags"`
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

/* -------------------- Deleting a category, all options ------------------- */

type usageResponse struct {
	Tags            int `json:"tags"`
	Events          int `json:"events"`
	ExclusiveEvents int `json:"exclusiveEvents"`
}

type eventResponse struct {
	Id          uint   `json:"id"`
	Description string `json:"description"`
	Tags        []struct {
		Id         uint `json:"id"`
		IdCategory uint `json:"idCategory"`
	} `json:"tags"`
}

// mustDo performs a request and fails the test unless it returns want.
func (c *client) mustDo(method, path string, body interface{}, want int) []byte {
	c.t.Helper()
	status, out := c.do(method, path, body)
	if status != want {
		c.t.Fatalf("%s %s: expected %d, got %d, body %s", method, path, want, status, out)
	}
	return out
}

func (c *client) categories() []categoryResponse {
	c.t.Helper()
	body := c.mustDo(http.MethodGet, "/categories", nil, http.StatusOK)
	var out []categoryResponse
	if err := json.Unmarshal(body, &out); err != nil {
		c.t.Fatalf("decode categories: %v", err)
	}
	return out
}

func (c *client) categoryOfKind(kind string) categoryResponse {
	c.t.Helper()
	for _, cat := range c.categories() {
		if cat.Kind == kind {
			return cat
		}
	}
	c.t.Fatalf("no %q category on the account", kind)
	return categoryResponse{}
}

func (c *client) events() []eventResponse {
	c.t.Helper()
	body := c.mustDo(http.MethodGet, "/events", nil, http.StatusOK)
	var out []eventResponse
	if err := json.Unmarshal(body, &out); err != nil {
		c.t.Fatalf("decode events: %v", err)
	}
	return out
}

func (c *client) findEvent(description string) *eventResponse {
	c.t.Helper()
	for i, e := range c.events() {
		if e.Description == description {
			return &c.events()[i]
		}
	}
	return nil
}

// newCategoryWithEvent creates a category holding one tag, and one event
// carrying that tag — the smallest fixture the three options differ on. The
// backend adds the month/year date tags to the event on its own.
func (c *client) newCategoryWithEvent(name, tagName, description string) (idCategory, idTag uint) {
	c.t.Helper()
	c.mustDo(http.MethodPost, "/categories", map[string]string{
		"category": name,
		"color":    "#abcdef",
	}, http.StatusCreated)

	for _, cat := range c.categories() {
		if cat.Category == name {
			idCategory = cat.Id
		}
	}
	if idCategory == 0 {
		c.t.Fatalf("category %q not found after its creation", name)
	}

	body := c.mustDo(http.MethodPost, "/tags", map[string]interface{}{
		"tag": tagName, "idCategory": idCategory,
	}, http.StatusCreated)
	var created struct {
		Id uint `json:"id"`
	}
	if err := json.Unmarshal(body, &created); err != nil {
		c.t.Fatalf("decode tag: %v", err)
	}
	idTag = created.Id

	c.mustDo(http.MethodPost, "/events", map[string]interface{}{
		"description": description,
		"date":        "2026-07-05T00:00:00Z",
		"tagsId":      []uint{idTag},
	}, http.StatusCreated)

	return idCategory, idTag
}

// TestCategoryDeleteOptions walks the three outcomes of the delete dialog over
// real HTTP: move the tags to Others, delete them keeping the events, or
// delete them with their events. It runs on a throwaway account, so the demo
// user never risks losing events and everything it creates dies with it.
//
// It adds one registration and one account deletion to the per-IP /login
// budget (10/min), which the rest of the suite leaves room for.
func TestCategoryDeleteOptions(t *testing.T) {
	email := fmt.Sprintf("e2e-catdel-%d@homl.local", time.Now().UnixNano())
	const pass = "Category1234!"

	c := newClient(t)
	c.register(email, pass)
	t.Cleanup(func() {
		c.do(http.MethodDelete, "/account", map[string]string{"password": pass})
	})

	other := c.categoryOfKind("other")

	t.Run("moving the tags keeps every tag and event", func(t *testing.T) {
		idCategory, idTag := c.newCategoryWithEvent("Hobbies", "Football", "e2e-move")

		var usage usageResponse
		body := c.mustDo(http.MethodGet, fmt.Sprintf("/categories/%d/usage", idCategory), nil, http.StatusOK)
		if err := json.Unmarshal(body, &usage); err != nil {
			t.Fatalf("decode usage: %v", err)
		}
		if usage.Tags != 1 || usage.Events != 1 || usage.ExclusiveEvents != 1 {
			t.Fatalf("usage before the deletion: %+v, want 1/1/1", usage)
		}

		c.mustDo(http.MethodDelete, fmt.Sprintf("/categories/%d", idCategory),
			map[string]bool{"moveTags": true}, http.StatusNoContent)

		for _, cat := range c.categories() {
			if cat.Id == idCategory {
				t.Fatal("the category survived its deletion")
			}
		}

		moved := false
		for _, tag := range c.categoryOfKind("other").Tags {
			if tag.Id == idTag {
				moved = true
			}
		}
		if !moved {
			t.Fatalf("tag %d was not moved to the Others category (%d)", idTag, other.Id)
		}

		event := c.findEvent("e2e-move")
		if event == nil {
			t.Fatal("the event must survive a move")
		}
		kept := false
		for _, tag := range event.Tags {
			if tag.Id == idTag {
				kept = true
			}
		}
		if !kept {
			t.Fatal("the event must keep the moved tag")
		}
	})

	t.Run("deleting the tags leaves the events with their date", func(t *testing.T) {
		idCategory, idTag := c.newCategoryWithEvent("Music", "Guitar", "e2e-keep")

		c.mustDo(http.MethodDelete, fmt.Sprintf("/categories/%d", idCategory),
			map[string]bool{"moveTags": false, "deleteEvents": false}, http.StatusNoContent)

		event := c.findEvent("e2e-keep")
		if event == nil {
			t.Fatal("the event must survive when the user chooses to keep it")
		}
		for _, tag := range event.Tags {
			if tag.Id == idTag {
				t.Fatal("the deleted tag is still on the event")
			}
		}
		if len(event.Tags) == 0 {
			t.Fatal("the event lost its date tags too")
		}
	})

	t.Run("deleting the tags with their events removes both", func(t *testing.T) {
		idCategory, _ := c.newCategoryWithEvent("Travel", "Japan", "e2e-delete")
		// A second event without any tag of the category must survive.
		c.mustDo(http.MethodPost, "/events", map[string]interface{}{
			"description": "e2e-untouched",
			"date":        "2026-07-05T00:00:00Z",
			"tagsId":      []uint{},
		}, http.StatusCreated)

		c.mustDo(http.MethodDelete, fmt.Sprintf("/categories/%d", idCategory),
			map[string]bool{"moveTags": false, "deleteEvents": true}, http.StatusNoContent)

		if c.findEvent("e2e-delete") != nil {
			t.Fatal("the event tagged from the category must be gone")
		}
		if c.findEvent("e2e-untouched") == nil {
			t.Fatal("an event of another category must survive")
		}
	})

	t.Run("a tag name already taken in Others is a conflict", func(t *testing.T) {
		idCategory, _ := c.newCategoryWithEvent("Cinema", "Dune", "e2e-clash")
		// The same name in Others is legal: tag names are unique per
		// category, which is exactly what makes the move impossible.
		c.mustDo(http.MethodPost, "/tags", map[string]interface{}{
			"tag": "Dune", "idCategory": other.Id,
		}, http.StatusCreated)

		status, body := c.do(http.MethodDelete, fmt.Sprintf("/categories/%d", idCategory),
			map[string]bool{"moveTags": true})
		if status != http.StatusConflict {
			t.Fatalf("DELETE with a taken tag name: expected 409, got %d, body %s", status, body)
		}

		var envelope struct {
			Error struct {
				Code    string `json:"code"`
				Message string `json:"message"`
			} `json:"error"`
		}
		if err := json.Unmarshal(body, &envelope); err != nil {
			t.Fatalf("decode error body: %v", err)
		}
		if envelope.Error.Code != "TAG_NAME_CONFLICT" {
			t.Fatalf("expected the TAG_NAME_CONFLICT code, got %q (body %s)", envelope.Error.Code, body)
		}
		if envelope.Error.Message == "" {
			t.Fatal("the conflict must carry a message for the client to fall back on")
		}

		// Nothing was moved and the event is untouched: the user can retry
		// with either of the two other options.
		found := false
		for _, cat := range c.categories() {
			if cat.Id == idCategory {
				found = true
			}
		}
		if !found {
			t.Fatal("the category must survive a refused move")
		}
		if c.findEvent("e2e-clash") == nil {
			t.Fatal("the event must survive a refused move")
		}

		c.mustDo(http.MethodDelete, fmt.Sprintf("/categories/%d", idCategory),
			map[string]bool{"moveTags": false, "deleteEvents": false}, http.StatusNoContent)
	})

	t.Run("the locked categories are refused", func(t *testing.T) {
		for _, kind := range []string{"date", "other"} {
			locked := c.categoryOfKind(kind)
			status, body := c.do(http.MethodDelete, fmt.Sprintf("/categories/%d", locked.Id),
				map[string]bool{"moveTags": false})
			if status != http.StatusForbidden {
				t.Fatalf("DELETE the %s category: expected 403, got %d, body %s", kind, status, body)
			}
		}
	})

	t.Run("someone else's category is not found", func(t *testing.T) {
		status, _ := c.do(http.MethodDelete, "/categories/999999999",
			map[string]bool{"moveTags": false})
		if status != http.StatusNotFound {
			t.Fatalf("DELETE an unknown category: expected 404, got %d", status)
		}
	})
}
