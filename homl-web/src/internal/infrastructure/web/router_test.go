package web

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

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

func (allowAllLimiter) Allow(string, int, time.Duration) (bool, error) { return true, nil }

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
	persons    *mocks.MockPersonsService
	settings   *mocks.MockSettingsService
}

func newTestServer() (*gin.Engine, *serverMocks) {
	sm := &serverMocks{
		users:      new(mocks.MockUsersService),
		categories: new(mocks.MockCategoriesService),
		events:     new(mocks.MockEventsService),
		tags:       new(mocks.MockTagsService),
		persons:    new(mocks.MockPersonsService),
		settings:   new(mocks.MockSettingsService),
	}
	authenticator := &TokenAuthenticator{Tokens: testJWT, Sessions: fakeSessions{}}
	server := &Server{
		Auth:        authenticator,
		RateLimiter: allowAllLimiter{},
		User:        &UserHandler{UsersService: sm.users, Tokens: testJWT},
		Category:    &CategoryHandler{CategoriesService: sm.categories},
		Tag:         &TagHandler{TagsService: sm.tags},
		Person:      &PersonHandler{PersonsService: sm.persons},
		Event:       &EventHandler{EventsService: sm.events},
		Settings:    &SettingsHandler{SettingsService: sm.settings},
	}
	router := SetupRouter(server, "", 5*time.Second, false, "")
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
		`{"username":"alan@sueur.ch","password":"masterdev","language":"fr"}`, "")

	assert.Equal(t, http.StatusOK, rec.Code)
	body := decodeJSON(t, rec)
	assert.NotEmpty(t, body["access_token"])
	assert.NotEmpty(t, body["refresh_token"])
	sm.users.AssertExpectations(t)
}

func TestRegistrationRejectsInvalidLanguage(t *testing.T) {
	router, _ := newTestServer()

	rec := doRequest(router, http.MethodPost, "/registration",
		`{"username":"alan@sueur.ch","password":"masterdev","language":"es"}`, "")

	assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
}

func TestLoginEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.users.On("Login", mock.AnythingOfType("*user.User")).
		Return(map[string]string{"access_token": "a", "refresh_token": "r"}, nil)

	rec := doRequest(router, http.MethodPost, "/login",
		`{"username":"alan@sueur.ch","password":"masterdev"}`, "")

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

func TestLogoutEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.users.On("Logout", mock.AnythingOfType("*user.AccessDetails")).Return(nil)

	rec := doRequest(router, http.MethodPost, "/logout", "", authHeader())

	assert.Equal(t, http.StatusNoContent, rec.Code)
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

func TestCreateCategoryEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.categories.On("CreateCategory", mock.AnythingOfType("*category.Category")).Return(nil)

	rec := doRequest(router, http.MethodPost, "/categories",
		`{"category":"Noces","color":"#ff0000"}`, authHeader())

	assert.Equal(t, http.StatusCreated, rec.Code)
	sm.categories.AssertExpectations(t)
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

func TestDeleteCategoryEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.categories.On("DeleteCategory", uint(5), testUserID, false).Return(nil)

	rec := doRequest(router, http.MethodDelete, "/categories/5", `{"moveTags":false}`, authHeader())

	assert.Equal(t, http.StatusNoContent, rec.Code)
	sm.categories.AssertExpectations(t)
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

func TestCreateEventEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.events.On("CreateEvent", testUserID, mock.AnythingOfType("*event.Event"), mock.Anything).Return(nil)

	rec := doRequest(router, http.MethodPost, "/events",
		`{"description":"cool","date":"1993-12-01T00:00:00Z","tagsId":[1,2]}`, authHeader())

	assert.Equal(t, http.StatusCreated, rec.Code)
	sm.events.AssertExpectations(t)
}

func TestCreateEventRejectsMissingDate(t *testing.T) {
	router, sm := newTestServer()

	rec := doRequest(router, http.MethodPost, "/events", `{"tagsId":[1]}`, authHeader())

	assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
	sm.events.AssertNotCalled(t, "CreateEvent", mock.Anything, mock.Anything, mock.Anything)
}

func TestDeleteEventEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.events.On("DeleteEvent", uint(9)).Return(nil)

	rec := doRequest(router, http.MethodDelete, "/events/9", "", authHeader())

	assert.Equal(t, http.StatusNoContent, rec.Code)
	sm.events.AssertExpectations(t)
}
