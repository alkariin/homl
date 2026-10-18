package web

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/auth"
	"github.com/alkariin/homl/homl-web/test/mocks"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

// fakeSessions is a session store that treats every well-formed access token as
// a live session for testUserID, so the auth middleware's session check passes
// in tests without a real Redis.
type fakeSessions struct{}

func (fakeSessions) FetchAuth(context.Context, *user.AccessDetails) (uint64, error) {
	return testUserID, nil
}

// allowAllLimiter is a no-op rate limiter for tests.
type allowAllLimiter struct{}

func (allowAllLimiter) Allow(context.Context, string, int, time.Duration) (bool, error) {
	return true, nil
}

// fakeE2EEFlags reports every test user as non-E2EE, matching the mocked
// services which expect plaintext values.
type fakeE2EEFlags struct{}

func (fakeE2EEFlags) IsEnabled(context.Context, uint64) (bool, error) {
	return false, nil
}

// These HTTP integration tests replace the old Postman suite: they boot the
// real Gin router (SetupRouter) wired with mocked services and assert the
// status code + JSON body for every request, exactly like the Postman test
// scripts did, but in-process and without any database.

const testUserID = uint64(1)

// testJWT backs both the auth middleware of the test router and the
// authHeader helper, so the tokens it mints are accepted end-to-end.
var testJWT = auth.NewJWT("test_access_secret", "test_refresh_secret", false)

func TestMain(m *testing.M) {
	gin.SetMode(gin.TestMode)
	os.Exit(m.Run())
}

type serverMocks struct {
	users      *mocks.MockUsersService
	categories *mocks.MockCategoriesService
	events     *mocks.MockEventsService
	tags       *mocks.MockTagsService
	tagGroups  *mocks.MockTagGroupsService
	settings   *mocks.MockSettingsService
	// handlers is the server the router was built from, so a test can flip
	// a handler setting (e.g. RegistrationClosed) after the fact.
	handlers *Server
}

func newTestServer() (*gin.Engine, *serverMocks) {
	sm := &serverMocks{
		users:      new(mocks.MockUsersService),
		categories: new(mocks.MockCategoriesService),
		events:     new(mocks.MockEventsService),
		tags:       new(mocks.MockTagsService),
		tagGroups:  new(mocks.MockTagGroupsService),
		settings:   new(mocks.MockSettingsService),
	}
	authenticator := &TokenAuthenticator{Tokens: testJWT, Sessions: fakeSessions{}}
	server := &Server{
		Auth:        authenticator,
		RateLimiter: allowAllLimiter{},
		E2EEFlags:   fakeE2EEFlags{},
		User:        &UserHandler{UsersService: sm.users, Tokens: testJWT},
		Category:    &CategoryHandler{CategoriesService: sm.categories},
		Tag:         &TagHandler{TagsService: sm.tags},
		TagGroup:    &TagGroupHandler{TagGroupsService: sm.tagGroups},
		Event:       &EventHandler{EventsService: sm.events},
		Settings:    &SettingsHandler{SettingsService: sm.settings},
	}
	sm.handlers = server
	router := SetupRouter(server, "", 5*time.Second, false, "", nil)
	return router, sm
}

// authHeader returns a Bearer token accepted by TokenAuthMiddleware for testUserID.
func authHeader() string {
	td, _ := testJWT.CreateToken(testUserID)
	return "Bearer " + td.AccessToken
}

func doRequest(router *gin.Engine, method, path, body, auth string) *httptest.ResponseRecorder {
	var reader *bytes.Reader
	if body == "" {
		reader = bytes.NewReader(nil)
	} else {
		reader = bytes.NewReader([]byte(body))
	}
	req, _ := http.NewRequest(method, path, reader)
	req.Header.Set("Content-Type", "application/json")
	if auth != "" {
		req.Header.Set("Authorization", auth)
	}
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

func decodeJSON(t *testing.T, rec *httptest.ResponseRecorder) map[string]interface{} {
	t.Helper()
	var out map[string]interface{}
	err := json.Unmarshal(rec.Body.Bytes(), &out)
	assert.NoError(t, err)
	return out
}

/* ------------------------------- Auth ----------------------------------- */

func TestRegistrationEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.users.On("Registration", mock.AnythingOfType("*user.User"), mock.AnythingOfType("*user.Language")).
		Return(map[string]string{"access_token": "a", "refresh_token": "r"}, nil)

	rec := doRequest(router, http.MethodPost, "/registration",
		`{"username":"someone@example.com","password":"masterdev","language":"fr"}`, "")

	assert.Equal(t, http.StatusOK, rec.Code)
	body := decodeJSON(t, rec)
	assert.NotEmpty(t, body["access_token"])
	assert.NotEmpty(t, body["refresh_token"])
	sm.users.AssertExpectations(t)
}

func TestRegistrationClosed(t *testing.T) {
	router, sm := newTestServer()
	sm.handlers.User.RegistrationClosed = true

	rec := doRequest(router, http.MethodPost, "/registration",
		`{"username":"someone@example.com","password":"masterdev","language":"fr"}`, "")

	assert.Equal(t, http.StatusForbidden, rec.Code)
	errBody := decodeJSON(t, rec)["error"].(map[string]interface{})
	assert.Equal(t, "REGISTRATION_CLOSED", errBody["code"])
	// Refused before the service is reached: no account is created.
	sm.users.AssertNotCalled(t, "Registration", mock.Anything, mock.Anything)
}

func TestRegistrationClosedRefusesEvenAnInvalidBody(t *testing.T) {
	router, sm := newTestServer()
	sm.handlers.User.RegistrationClosed = true

	rec := doRequest(router, http.MethodPost, "/registration", `{}`, "")

	assert.Equal(t, http.StatusForbidden, rec.Code)
}

func TestRegistrationStatus(t *testing.T) {
	router, sm := newTestServer()

	// Public: no Authorization header.
	rec := doRequest(router, http.MethodGet, "/registration", "", "")
	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, true, decodeJSON(t, rec)["open"])

	sm.handlers.User.RegistrationClosed = true
	rec = doRequest(router, http.MethodGet, "/registration", "", "")
	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, false, decodeJSON(t, rec)["open"])
}

func TestRegistrationRejectsInvalidLanguage(t *testing.T) {
	router, _ := newTestServer()

	rec := doRequest(router, http.MethodPost, "/registration",
		`{"username":"someone@example.com","password":"masterdev","language":"es"}`, "")

	assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
}

func TestLoginEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.users.On("Login", mock.AnythingOfType("*user.User")).
		Return(map[string]string{"access_token": "a", "refresh_token": "r"}, nil)

	rec := doRequest(router, http.MethodPost, "/login",
		`{"username":"someone@example.com","password":"masterdev"}`, "")

	assert.Equal(t, http.StatusOK, rec.Code)
	body := decodeJSON(t, rec)
	assert.NotEmpty(t, body["access_token"])
	assert.NotEmpty(t, body["refresh_token"])
	sm.users.AssertExpectations(t)
}

func TestLoginRejectsBadEmail(t *testing.T) {
	router, _ := newTestServer()

	rec := doRequest(router, http.MethodPost, "/login",
		`{"username":"not-an-email","password":"masterdev"}`, "")

	assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
}

func TestRefreshEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.users.On("Refresh", mock.AnythingOfType("*user.RefreshInput")).
		Return(map[string]string{"access_token": "a", "refresh_token": "r"}, nil)

	rec := doRequest(router, http.MethodPost, "/refresh",
		`{"refresh_token":"some-refresh-token"}`, "")

	assert.Equal(t, http.StatusCreated, rec.Code)
	body := decodeJSON(t, rec)
	assert.NotEmpty(t, body["access_token"])
	sm.users.AssertExpectations(t)
}

// A refresh missing the account's second factor reaches the client as a 401
// naming the factor, so it can prompt for it and retry instead of treating
// the refusal as a dead session.
func TestRefreshReportsTheMissingSecondFactor(t *testing.T) {
	cases := []struct {
		factor  string
		message string
	}{
		{apperror.FactorPin, "Pin must be provided"},
		{apperror.FactorFingerprint, "Signature must be provided"},
	}

	for _, c := range cases {
		t.Run(c.factor, func(t *testing.T) {
			router, sm := newTestServer()
			sm.users.On("Refresh", mock.AnythingOfType("*user.RefreshInput")).
				Return(nil, apperror.NewSecondFactorRequired(c.factor))

			rec := doRequest(router, http.MethodPost, "/refresh",
				`{"refresh_token":"some-refresh-token"}`, "")

			assert.Equal(t, http.StatusUnauthorized, rec.Code)
			assert.JSONEq(t,
				`{"error":{"type":"AUTHORIZATION","message":"`+c.message+`","code":"SECOND_FACTOR_REQUIRED","factor":"`+c.factor+`"}}`,
				rec.Body.String())
			sm.users.AssertExpectations(t)
		})
	}
}

func TestLogoutEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.users.On("Logout", mock.AnythingOfType("*user.AccessDetails")).Return(nil)

	rec := doRequest(router, http.MethodPost, "/logout", "", authHeader())

	assert.Equal(t, http.StatusNoContent, rec.Code)
	sm.users.AssertExpectations(t)
}

func TestDeleteAccountEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.users.On("DeleteAccount", "Delete1234!", testUserID).Return(nil)

	rec := doRequest(router, http.MethodDelete, "/account", `{"password":"Delete1234!"}`, authHeader())

	assert.Equal(t, http.StatusNoContent, rec.Code)
	sm.users.AssertExpectations(t)
}

func TestDeleteAccountRequiresToken(t *testing.T) {
	router, sm := newTestServer()

	rec := doRequest(router, http.MethodDelete, "/account", `{"password":"Delete1234!"}`, "")

	assert.Equal(t, http.StatusUnauthorized, rec.Code)
	sm.users.AssertNotCalled(t, "DeleteAccount")
}

func TestDeleteAccountRejectsMissingPassword(t *testing.T) {
	router, sm := newTestServer()

	for _, body := range []string{`{"password":""}`, `{}`, ``} {
		rec := doRequest(router, http.MethodDelete, "/account", body, authHeader())
		assert.Equal(t, http.StatusUnprocessableEntity, rec.Code, "body %q", body)
	}

	sm.users.AssertNotCalled(t, "DeleteAccount")
}

func TestDeleteAccountRejectsWrongPassword(t *testing.T) {
	router, sm := newTestServer()

	sm.users.On("DeleteAccount", "WrongPass123!", testUserID).Return(apperror.NewAuthorization("Not authorized"))

	rec := doRequest(router, http.MethodDelete, "/account", `{"password":"WrongPass123!"}`, authHeader())

	assert.Equal(t, http.StatusUnauthorized, rec.Code)
	sm.users.AssertExpectations(t)
}

/* --------------------------- Auth middleware ---------------------------- */

func TestProtectedRouteRequiresToken(t *testing.T) {
	router, _ := newTestServer()

	rec := doRequest(router, http.MethodGet, "/categories", "", "")

	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestProtectedRouteRejectsInvalidToken(t *testing.T) {
	router, _ := newTestServer()

	rec := doRequest(router, http.MethodGet, "/categories", "", "Bearer garbage")

	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

/* ----------------------------- Categories ------------------------------- */

func TestGetCategoriesEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.categories.On("GetCategories", testUserID).Return([]category.GetCategoryResponse{
		{Id: 1, Category: "Dates", Color: "#ffff60", IsLocked: true},
	}, nil)

	rec := doRequest(router, http.MethodGet, "/categories", "", authHeader())

	assert.Equal(t, http.StatusOK, rec.Code)
	var out []category.GetCategoryResponse
	assert.NoError(t, json.Unmarshal(rec.Body.Bytes(), &out))
	assert.Len(t, out, 1)
	assert.Equal(t, "Dates", out[0].Category)
	sm.categories.AssertExpectations(t)
}

// The new id comes back in the body, like POST /tags: a client that created
// the category (offline replays included) must be able to address it without
// refetching the whole list.
func TestCreateCategoryEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.categories.On("CreateCategory", mock.AnythingOfType("*category.Category")).Return(uint(7), true, nil)

	rec := doRequest(router, http.MethodPost, "/categories",
		`{"category":"Noces","color":"#ff0000"}`, authHeader())

	assert.Equal(t, http.StatusCreated, rec.Code)
	assert.Equal(t, map[string]interface{}{"id": float64(7)}, decodeJSON(t, rec))
	sm.categories.AssertExpectations(t)
}

// A create carrying a clientId already used answers 200 with the first
// category: the offline replay of a create whose answer was lost.
func TestCreateCategoryEndpointReplay(t *testing.T) {
	const clientId = "5b0e6a3c-2f4d-4a51-9c1e-7d2b8f6a9e10"
	router, sm := newTestServer()
	sm.categories.On("CreateCategory", mock.MatchedBy(func(c *category.Category) bool {
		return c.ClientId != nil && *c.ClientId == clientId
	})).Return(uint(7), false, nil)

	rec := doRequest(router, http.MethodPost, "/categories",
		`{"category":"Noces","color":"#ff0000","clientId":"`+clientId+`"}`, authHeader())

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, map[string]interface{}{"id": float64(7)}, decodeJSON(t, rec))
	sm.categories.AssertExpectations(t)

	rec = doRequest(router, http.MethodPost, "/categories",
		`{"category":"Noces","color":"#ff0000","clientId":"not-a-uuid"}`, authHeader())
	assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
}

func TestCreateCategoryRejectsNonHexColor(t *testing.T) {
	router, sm := newTestServer()

	rec := doRequest(router, http.MethodPost, "/categories",
		`{"category":"Noces","color":"red"}`, authHeader())

	assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
	sm.categories.AssertNotCalled(t, "CreateCategory", mock.Anything)
}

func TestUpdateCategoryEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.categories.On("UpdateCategory", mock.AnythingOfType("*category.Category")).Return(nil)

	rec := doRequest(router, http.MethodPatch, "/categories/5",
		`{"category":"Autres","color":"#ff0000"}`, authHeader())

	assert.Equal(t, http.StatusNoContent, rec.Code)
	sm.categories.AssertExpectations(t)
}

// TestDeleteCategoryEndpoint pins the wire contract of the three options of
// the delete dialog: which body the client sends, and which flags the service
// must receive for it.
func TestDeleteCategoryEndpoint(t *testing.T) {
	cases := []struct {
		name         string
		body         string
		moveTags     bool
		deleteEvents bool
	}{
		{"move the tags to the Other category", `{"moveTags":true,"deleteEvents":false}`, true, false},
		{"delete the tags, keep the events", `{"moveTags":false,"deleteEvents":false}`, false, false},
		{"delete the tags and their events", `{"moveTags":false,"deleteEvents":true}`, false, true},
		// Older clients omit the flag they do not use: both default to false,
		// the option that destroys the least.
		{"an omitted deleteEvents defaults to false", `{"moveTags":true}`, true, false},
		{"an empty body deletes the tags and keeps the events", `{}`, false, false},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			router, sm := newTestServer()

			sm.categories.On("DeleteCategory", uint(5), testUserID, c.moveTags, c.deleteEvents).Return(nil)

			rec := doRequest(router, http.MethodDelete, "/categories/5", c.body, authHeader())

			assert.Equal(t, http.StatusNoContent, rec.Code)
			sm.categories.AssertExpectations(t)
		})
	}
}

func TestDeleteCategoryRejectsMalformedRequests(t *testing.T) {
	cases := []struct {
		name string
		path string
		body string
	}{
		{"a broken body", "/categories/5", `{"moveTags":`},
		{"a non-boolean flag", "/categories/5", `{"moveTags":"yes"}`},
		{"a missing body", "/categories/5", ``},
		{"a non-numeric id", "/categories/abc", `{"moveTags":true}`},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			router, sm := newTestServer()

			rec := doRequest(router, http.MethodDelete, c.path, c.body, authHeader())

			assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
			// Nothing may reach the service: a malformed request must never
			// delete anything.
			sm.categories.AssertNotCalled(t, "DeleteCategory")
		})
	}
}

func TestDeleteCategoryRequiresToken(t *testing.T) {
	router, sm := newTestServer()

	rec := doRequest(router, http.MethodDelete, "/categories/5", `{"moveTags":true}`, "")

	assert.Equal(t, http.StatusUnauthorized, rec.Code)
	sm.categories.AssertNotCalled(t, "DeleteCategory")
}

// TestDeleteCategoryPropagatesServiceErrors checks that the refusals of the
// persistence layer keep their status through the handler: a locked category
// must not read as a server error, nor someone else's id as forbidden.
func TestDeleteCategoryPropagatesServiceErrors(t *testing.T) {
	cases := []struct {
		name   string
		err    error
		status int
	}{
		{"a locked category is forbidden", apperror.NewStatusForbidden(), http.StatusForbidden},
		{"an unknown category is not found", apperror.NewNotFound("category", "5"), http.StatusNotFound},
		{"a taken tag name is a conflict", apperror.NewTagNameConflict("taken"), http.StatusConflict},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			router, sm := newTestServer()

			sm.categories.On("DeleteCategory", uint(5), testUserID, false, false).Return(c.err)

			rec := doRequest(router, http.MethodDelete, "/categories/5", `{"moveTags":false}`, authHeader())

			assert.Equal(t, c.status, rec.Code)
			sm.categories.AssertExpectations(t)
		})
	}
}

// A move refused because a tag name is already taken in Other must reach the
// client as a 409 carrying its code: the app keys its message off the code,
// never off the message string.
func TestDeleteCategoryReportsTheTagNameConflict(t *testing.T) {
	router, sm := newTestServer()

	sm.categories.On("DeleteCategory", uint(5), testUserID, true, false).
		Return(apperror.NewTagNameConflict("A tag of this category already exists in the Other category"))

	rec := doRequest(router, http.MethodDelete, "/categories/5", `{"moveTags":true}`, authHeader())

	assert.Equal(t, http.StatusConflict, rec.Code)
	body := decodeJSON(t, rec)
	errBody, ok := body["error"].(map[string]interface{})
	assert.True(t, ok, "the error envelope must be an object, got %v", body["error"])
	assert.Equal(t, apperror.CodeTagNameConflict, errBody["code"])
	assert.NotEmpty(t, errBody["message"])
	sm.categories.AssertExpectations(t)
}

func TestCategoryUsageEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.categories.On("GetCategoryUsage", uint(5), testUserID).
		Return(&category.CategoryUsage{Tags: 3, Events: 8, ExclusiveEvents: 2}, nil)

	rec := doRequest(router, http.MethodGet, "/categories/5/usage", "", authHeader())

	assert.Equal(t, http.StatusOK, rec.Code)
	var out category.CategoryUsage
	assert.NoError(t, json.Unmarshal(rec.Body.Bytes(), &out))
	assert.Equal(t, 3, out.Tags)
	assert.Equal(t, 8, out.Events)
	assert.Equal(t, 2, out.ExclusiveEvents)
	sm.categories.AssertExpectations(t)
}

// The dialog is built from these counts, so a category the user does not own
// must fail the lookup instead of leaking someone else's numbers.
func TestCategoryUsageRejectsAnotherUsersCategory(t *testing.T) {
	router, sm := newTestServer()

	sm.categories.On("GetCategoryUsage", uint(5), testUserID).
		Return(nil, apperror.NewNotFound("category", "5"))

	rec := doRequest(router, http.MethodGet, "/categories/5/usage", "", authHeader())

	assert.Equal(t, http.StatusNotFound, rec.Code)
	sm.categories.AssertExpectations(t)
}

/* -------------------------------- Tags ---------------------------------- */

func TestCreateTagEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.tags.On("CreateTag", testUserID, mock.AnythingOfType("*category.Tag")).Return(uint(12), nil)

	rec := doRequest(router, http.MethodPost, "/tags",
		`{"tag":"Football","idCategory":2}`, authHeader())

	assert.Equal(t, http.StatusCreated, rec.Code)
	assert.Equal(t, float64(12), decodeJSON(t, rec)["id"])
	sm.tags.AssertExpectations(t)
}

func TestUpdateTagEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.tags.On("UpdateTag", testUserID, mock.AnythingOfType("*category.Tag")).Return(nil)

	rec := doRequest(router, http.MethodPatch, "/tags/12",
		`{"tag":"Football","idCategory":2}`, authHeader())

	assert.Equal(t, http.StatusNoContent, rec.Code)
	sm.tags.AssertExpectations(t)
}

// Tag names are unique per category, so creating or moving one onto a taken
// name is refused. It must reach the client as a 409 carrying its code: the
// app keys its message off the code, never off the message string.
func TestTagEndpointsReportTheNameConflict(t *testing.T) {
	cases := []struct {
		name   string
		method string
		path   string
		on     func(sm *serverMocks)
	}{
		{
			"creating a tag whose name is taken", http.MethodPost, "/tags",
			func(sm *serverMocks) {
				sm.tags.On("CreateTag", testUserID, mock.AnythingOfType("*category.Tag")).
					Return(uint(0), apperror.NewTagNameConflict("A tag with this name already exists in this category"))
			},
		},
		{
			"renaming or moving onto a taken name", http.MethodPatch, "/tags/12",
			func(sm *serverMocks) {
				sm.tags.On("UpdateTag", testUserID, mock.AnythingOfType("*category.Tag")).
					Return(apperror.NewTagNameConflict("A tag with this name already exists in the target category"))
			},
		},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			router, sm := newTestServer()
			c.on(sm)

			rec := doRequest(router, c.method, c.path, `{"tag":"Football","idCategory":2}`, authHeader())

			assert.Equal(t, http.StatusConflict, rec.Code)
			body := decodeJSON(t, rec)
			errBody, ok := body["error"].(map[string]interface{})
			assert.True(t, ok, "the error envelope must be an object, got %v", body["error"])
			assert.Equal(t, apperror.CodeTagNameConflict, errBody["code"])
			assert.NotEmpty(t, errBody["message"])
			sm.tags.AssertExpectations(t)
		})
	}
}

/* ------------------------------ Tag groups ------------------------------ */

func TestCreateTagGroupEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.tagGroups.On("CreateTagGroup", testUserID, mock.MatchedBy(func(g *category.TagGroup) bool {
		return g.Name == "Family" && g.IdCategory == 2 &&
			len(g.Members) == 2 && g.Members[0] == 10 && g.Members[1] == 11
	})).Return(uint(5), nil)

	rec := doRequest(router, http.MethodPost, "/tagGroups",
		`{"name":"Family","idCategory":2,"members":[10,11]}`, authHeader())

	assert.Equal(t, http.StatusCreated, rec.Code)
	assert.Equal(t, map[string]interface{}{"id": float64(5)}, decodeJSON(t, rec))
	sm.tagGroups.AssertExpectations(t)
}

func TestCreateTagGroupRejectsMissingFields(t *testing.T) {
	for _, body := range []string{
		`{"idCategory":2,"members":[10]}`,
		`{"name":"Family","members":[10]}`,
	} {
		router, sm := newTestServer()

		rec := doRequest(router, http.MethodPost, "/tagGroups", body, authHeader())

		assert.Equal(t, http.StatusUnprocessableEntity, rec.Code, body)
		sm.tagGroups.AssertNotCalled(t, "CreateTagGroup", mock.Anything, mock.Anything)
	}
}

func TestUpdateTagGroupEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.tagGroups.On("UpdateTagGroup", testUserID, mock.MatchedBy(func(g *category.TagGroup) bool {
		return g.Id == 5 && g.Name == "Family" && len(g.Members) == 1
	})).Return(nil)

	rec := doRequest(router, http.MethodPatch, "/tagGroups/5",
		`{"name":"Family","members":[10]}`, authHeader())

	assert.Equal(t, http.StatusNoContent, rec.Code)
	sm.tagGroups.AssertExpectations(t)
}

func TestDeleteTagGroupEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.tagGroups.On("DeleteTagGroup", uint(5), testUserID).Return(nil)

	rec := doRequest(router, http.MethodDelete, "/tagGroups/5", "", authHeader())

	assert.Equal(t, http.StatusNoContent, rec.Code)
	sm.tagGroups.AssertExpectations(t)
}

// Group names are unique per category, like tag names, and the refusal
// carries the same code.
func TestTagGroupEndpointsReportTheNameConflict(t *testing.T) {
	router, sm := newTestServer()

	sm.tagGroups.On("CreateTagGroup", testUserID, mock.AnythingOfType("*category.TagGroup")).
		Return(uint(0), apperror.NewTagNameConflict("A group with this name already exists in this category"))

	rec := doRequest(router, http.MethodPost, "/tagGroups",
		`{"name":"Family","idCategory":2,"members":[10]}`, authHeader())

	assert.Equal(t, http.StatusConflict, rec.Code)
	errBody, ok := decodeJSON(t, rec)["error"].(map[string]interface{})
	assert.True(t, ok)
	assert.Equal(t, apperror.CodeTagNameConflict, errBody["code"])
	sm.tagGroups.AssertExpectations(t)
}

/* ------------------------------- Events --------------------------------- */

func TestGetEventsEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.events.On("GetEvents", testUserID, mock.Anything).Return([]event.GetEventsResponse{
		{Event: event.Event{Id: 1, Description: "cool"}},
	}, nil)

	rec := doRequest(router, http.MethodGet, "/events", `{"tags":[]}`, authHeader())

	assert.Equal(t, http.StatusOK, rec.Code)
	var out []event.GetEventsResponse
	assert.NoError(t, json.Unmarshal(rec.Body.Bytes(), &out))
	assert.Len(t, out, 1)
	sm.events.AssertExpectations(t)
}

// The new id comes back in the body, like POST /tags: a client that created
// the event (offline replays included) must be able to edit or delete it
// without refetching the whole list.
func TestCreateEventEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.events.On("CreateEvent", testUserID, mock.AnythingOfType("*event.Event"), mock.Anything).Return(uint(33), true, nil)

	rec := doRequest(router, http.MethodPost, "/events",
		`{"description":"cool","date":"1993-12-01T00:00:00Z","tagsId":[1,2]}`, authHeader())

	assert.Equal(t, http.StatusCreated, rec.Code)
	assert.Equal(t, map[string]interface{}{"id": float64(33)}, decodeJSON(t, rec))
	sm.events.AssertExpectations(t)
}

// A create carrying a clientId already used answers 200 with the first
// event: the client lost the answer to its first try and sent it again.
func TestCreateEventEndpointReplay(t *testing.T) {
	const clientId = "5b0e6a3c-2f4d-4a51-9c1e-7d2b8f6a9e10"
	router, sm := newTestServer()
	sm.events.On("CreateEvent", testUserID, mock.MatchedBy(func(evt *event.Event) bool {
		return evt.ClientId != nil && *evt.ClientId == clientId
	}), []uint{1}).Return(uint(33), false, nil)

	rec := doRequest(router, http.MethodPost, "/events",
		`{"date":"1993-12-01T00:00:00Z","tagsId":[1],"clientId":"`+clientId+`"}`, authHeader())

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, map[string]interface{}{"id": float64(33)}, decodeJSON(t, rec))
	sm.events.AssertExpectations(t)
}

func TestCreateEventRejectsAClientIdThatIsNotAUUID(t *testing.T) {
	router, sm := newTestServer()

	rec := doRequest(router, http.MethodPost, "/events",
		`{"date":"1993-12-01T00:00:00Z","tagsId":[1],"clientId":"not-a-uuid"}`, authHeader())

	assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
	sm.events.AssertNotCalled(t, "CreateEvent", mock.Anything, mock.Anything, mock.Anything)
}

// GET /settings carries the data generation the offline client compares its
// pending writes with.
func TestGetSettingsCarriesTheDataGeneration(t *testing.T) {
	router, sm := newTestServer()
	sm.settings.On("GetSettings", testUserID).Return(&user.SettingsResponse{
		Language:       "en",
		DataGeneration: "0b9a2c6e-8f61-4d3a-a5e2-1c7f0d4b9e83",
	}, nil)

	rec := doRequest(router, http.MethodGet, "/settings", "", authHeader())

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, "0b9a2c6e-8f61-4d3a-a5e2-1c7f0d4b9e83", decodeJSON(t, rec)["dataGeneration"])
}

// The period fields reach the service as parsed: a closed period keeps its
// end date, an open one its flag.
func TestCreateEventEndpointForwardsThePeriod(t *testing.T) {
	end := time.Date(2026, time.July, 5, 0, 0, 0, 0, time.UTC)

	t.Run("closed period", func(t *testing.T) {
		router, sm := newTestServer()
		sm.events.On("CreateEvent", testUserID, mock.MatchedBy(func(evt *event.Event) bool {
			return evt.EndDate != nil && evt.EndDate.Equal(end) && !evt.IsOngoing
		}), []uint{1}).Return(uint(1), true, nil)

		rec := doRequest(router, http.MethodPost, "/events",
			`{"date":"2026-06-28T00:00:00Z","endDate":"2026-07-05T00:00:00Z","tagsId":[1]}`, authHeader())

		assert.Equal(t, http.StatusCreated, rec.Code)
		sm.events.AssertExpectations(t)
	})

	t.Run("open period", func(t *testing.T) {
		router, sm := newTestServer()
		sm.events.On("CreateEvent", testUserID, mock.MatchedBy(func(evt *event.Event) bool {
			return evt.EndDate == nil && evt.IsOngoing
		}), []uint{}).Return(uint(1), true, nil)

		rec := doRequest(router, http.MethodPost, "/events",
			`{"date":"2024-06-03T00:00:00Z","isOngoing":true,"tagsId":[]}`, authHeader())

		assert.Equal(t, http.StatusCreated, rec.Code)
		sm.events.AssertExpectations(t)
	})

	// An explicit null and an omitted endDate mean the same thing on the wire.
	t.Run("null end date", func(t *testing.T) {
		router, sm := newTestServer()
		sm.events.On("CreateEvent", testUserID, mock.MatchedBy(func(evt *event.Event) bool {
			return evt.EndDate == nil && !evt.IsOngoing
		}), []uint{}).Return(uint(1), true, nil)

		rec := doRequest(router, http.MethodPost, "/events",
			`{"date":"2026-06-03T00:00:00Z","endDate":null,"tagsId":[]}`, authHeader())

		assert.Equal(t, http.StatusCreated, rec.Code)
		sm.events.AssertExpectations(t)
	})
}

func TestUpdateEventEndpointForwardsThePeriod(t *testing.T) {
	router, sm := newTestServer()

	end := time.Date(2026, time.August, 31, 0, 0, 0, 0, time.UTC)
	sm.events.On("UpdateEvent", testUserID, mock.MatchedBy(func(evt *event.Event) bool {
		return evt.Id == 9 && evt.EndDate != nil && evt.EndDate.Equal(end) && !evt.IsOngoing
	}), []uint{1}).Return(nil)

	// Closing an open period: the full-state PATCH carries the end date and
	// leaves isOngoing out, which resets it.
	rec := doRequest(router, http.MethodPatch, "/events/9",
		`{"description":"job","date":"2024-06-03T00:00:00Z","endDate":"2026-08-31T00:00:00Z","tagsId":[1]}`, authHeader())

	assert.Equal(t, http.StatusNoContent, rec.Code)
	sm.events.AssertExpectations(t)
}

// The period invariants live in the service (application.validatePeriod); its
// 400 has to reach the client as one, message included.
func TestCreateEventEndpointRelaysAPeriodError(t *testing.T) {
	router, sm := newTestServer()

	sm.events.On("CreateEvent", testUserID, mock.Anything, mock.Anything).
		Return(uint(0), false, apperror.NewBadRequest("The end date cannot precede the start date"))

	rec := doRequest(router, http.MethodPost, "/events",
		`{"date":"2026-06-18T00:00:00Z","endDate":"2026-06-03T00:00:00Z","tagsId":[]}`, authHeader())

	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "end date cannot precede")
}

func TestCreateEventRejectsMissingDate(t *testing.T) {
	router, sm := newTestServer()

	rec := doRequest(router, http.MethodPost, "/events", `{"tagsId":[1]}`, authHeader())

	assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
	sm.events.AssertNotCalled(t, "CreateEvent", mock.Anything, mock.Anything, mock.Anything)
}

func TestDeleteEventEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.events.On("DeleteEvent", uint(9), testUserID).Return(nil)

	rec := doRequest(router, http.MethodDelete, "/events/9", "", authHeader())

	assert.Equal(t, http.StatusNoContent, rec.Code)
	sm.events.AssertExpectations(t)
}

/* --------------------------- Conditional reads -------------------------- */

func doConditional(router *gin.Engine, path, ifNoneMatch string) *httptest.ResponseRecorder {
	req, _ := http.NewRequest(http.MethodGet, path, nil)
	req.Header.Set("Authorization", authHeader())
	if ifNoneMatch != "" {
		req.Header.Set("If-None-Match", ifNoneMatch)
	}
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

func TestEventsCarryAnETagAndAnswer304WhenUnchanged(t *testing.T) {
	router, sm := newTestServer()
	sm.events.On("GetEvents", testUserID, mock.Anything).Return([]event.GetEventsResponse{
		{Event: event.Event{Id: 1, Description: "cool"}},
	}, nil)

	first := doConditional(router, "/events", "")
	assert.Equal(t, http.StatusOK, first.Code)
	etag := first.Header().Get("ETag")
	assert.Regexp(t, `^"[A-Za-z0-9_-]{24}"$`, etag)
	assert.Equal(t, "no-store", first.Header().Get("Cache-Control"))

	// The client holds that body: nothing is sent again.
	again := doConditional(router, "/events", etag)
	assert.Equal(t, http.StatusNotModified, again.Code)
	assert.Empty(t, again.Body.Bytes())
	assert.Equal(t, etag, again.Header().Get("ETag"))

	// A weak form, or a list holding it, names it too.
	assert.Equal(t, http.StatusNotModified, doConditional(router, "/events", "W/"+etag).Code)
	assert.Equal(t, http.StatusNotModified, doConditional(router, "/events", `"other", `+etag).Code)

	// Another fingerprint: the body comes.
	stale := doConditional(router, "/events", `"stale"`)
	assert.Equal(t, http.StatusOK, stale.Code)
	assert.Equal(t, first.Body.Bytes(), stale.Body.Bytes())
}

func TestTheETagFollowsTheData(t *testing.T) {
	router, sm := newTestServer()
	sm.events.On("GetEvents", testUserID, mock.Anything).Return([]event.GetEventsResponse{
		{Event: event.Event{Id: 1, Description: "cool"}},
	}, nil).Once()
	sm.events.On("GetEvents", testUserID, mock.Anything).Return([]event.GetEventsResponse{
		{Event: event.Event{Id: 1, Description: "edited elsewhere"}},
	}, nil).Once()

	etag := doConditional(router, "/events", "").Header().Get("ETag")
	changed := doConditional(router, "/events", etag)

	assert.Equal(t, http.StatusOK, changed.Code)
	assert.NotEqual(t, etag, changed.Header().Get("ETag"))
	assert.Contains(t, changed.Body.String(), "edited elsewhere")
}

func TestCategoriesCarryAnETag(t *testing.T) {
	router, sm := newTestServer()
	sm.categories.On("GetCategories", testUserID).Return([]category.GetCategoryResponse{
		{Id: 1, Category: "Dates"},
	}, nil)

	etag := doConditional(router, "/categories", "").Header().Get("ETag")
	assert.NotEmpty(t, etag)
	assert.Equal(t, http.StatusNotModified, doConditional(router, "/categories", etag).Code)
}

func TestAFailedReadGetsNoETag(t *testing.T) {
	router, sm := newTestServer()
	sm.events.On("GetEvents", testUserID, mock.Anything).Return(nil, errors.New("db down"))

	rec := doConditional(router, "/events", "*")

	assert.Equal(t, http.StatusInternalServerError, rec.Code)
	assert.Empty(t, rec.Header().Get("ETag"))
	assert.Contains(t, rec.Body.String(), "INTERNAL")
}

func TestABrowserMaySendAndReadTheETag(t *testing.T) {
	router, _ := newTestServer()

	req, _ := http.NewRequest(http.MethodOptions, "/events", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Contains(t, rec.Header().Get("Access-Control-Allow-Headers"), "If-None-Match")
	assert.Equal(t, "ETag", rec.Header().Get("Access-Control-Expose-Headers"))
}

/* ----------------------------- Device sessions --------------------------- */

func TestListSessionsEndpoint(t *testing.T) {
	router, sm := newTestServer()
	sm.users.On("ListSessions", mock.MatchedBy(func(ad *user.AccessDetails) bool {
		return ad.UserId == testUserID && ad.AccessUuid != ""
	})).Return([]user.Session{{Id: "phone", Client: "android 0.5.0", Current: true}}, nil)

	rec := doRequest(router, http.MethodGet, "/sessions", "", authHeader())

	assert.Equal(t, http.StatusOK, rec.Code)
	var out []map[string]interface{}
	assert.NoError(t, json.Unmarshal(rec.Body.Bytes(), &out))
	assert.Equal(t, "phone", out[0]["id"])
	assert.Equal(t, true, out[0]["current"])
	assert.Contains(t, out[0], "createdAt")

	assert.Equal(t, http.StatusUnauthorized, doRequest(router, http.MethodGet, "/sessions", "", "").Code)
}

func TestRevokeSessionEndpoints(t *testing.T) {
	router, sm := newTestServer()
	sm.users.On("RevokeSession", testUserID, "phone").Return(nil)
	sm.users.On("RevokeSession", testUserID, "nope").Return(apperror.NewNotFound("session", "nope"))
	sm.users.On("RevokeOtherSessions", mock.Anything).Return(nil)

	assert.Equal(t, http.StatusNoContent, doRequest(router, http.MethodDelete, "/sessions/phone", "", authHeader()).Code)
	assert.Equal(t, http.StatusNotFound, doRequest(router, http.MethodDelete, "/sessions/nope", "", authHeader()).Code)
	assert.Equal(t, http.StatusNoContent, doRequest(router, http.MethodDelete, "/sessions", "", authHeader()).Code)
	sm.users.AssertExpectations(t)
}

func TestClientInfoReachesTheServices(t *testing.T) {
	engine := gin.New()
	engine.Use(ClientInfo())
	var seen user.SessionInfo
	engine.GET("/probe", func(c *gin.Context) {
		seen = user.SessionInfoFrom(c.Request.Context())
	})

	req, _ := http.NewRequest(http.MethodGet, "/probe", nil)
	req.Header.Set("X-Homl-Client", "  android 0.5.0\x07  ")
	req.RemoteAddr = "192.0.2.7:4242"
	engine.ServeHTTP(httptest.NewRecorder(), req)

	assert.Equal(t, "android 0.5.0", seen.Client, "trimmed, without control characters")
	assert.Equal(t, "192.0.2.7", seen.IP)
}

func TestTheClientLabelIsBounded(t *testing.T) {
	assert.Len(t, []rune(clientLabel(strings.Repeat("\u00e9", 200))), maxClientLength)
	assert.Equal(t, "", clientLabel(""))
}
