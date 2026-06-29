package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/alkariin/homl/homl-web/internal/category"
	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/event"
	"github.com/alkariin/homl/homl-web/internal/mocks"
	"github.com/alkariin/homl/homl-web/internal/person"
	"github.com/alkariin/homl/homl-web/internal/settings"
	"github.com/alkariin/homl/homl-web/internal/shared"
	"github.com/alkariin/homl/homl-web/internal/tag"
	"github.com/alkariin/homl/homl-web/internal/user"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

// These HTTP integration tests replace the old Postman suite: they boot the
// real Gin router (SetupRouter) wired with mocked services and assert the
// status code + JSON body for every request, exactly like the Postman test
// scripts did, but in-process and without any database.

const testUserID = uint64(1)

func TestMain(m *testing.M) {
	os.Setenv("ENVIRONMENT", "TEST")
	os.Setenv("ACCESS_SECRET", "test_access_secret")
	os.Setenv("REFRESH_SECRET", "test_refresh_secret")
	os.Setenv("ENCRYPT_SECRET", "01234567890123456789012345678901")
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
	server := &Server{
		User:     &user.Handler{UsersService: sm.users},
		Category: &category.Handler{CategoriesService: sm.categories, UsersService: sm.users},
		Tag:      &tag.Handler{TagsService: sm.tags, UsersService: sm.users},
		Person:   &person.Handler{PersonsService: sm.persons, UsersService: sm.users},
		Event:    &event.Handler{EventsService: sm.events, UsersService: sm.users},
		Settings: &settings.Handler{SettingsService: sm.settings, UsersService: sm.users},
	}
	router := SetupRouter(server, "", 5*time.Second)
	return router, sm
}

// authHeader returns a Bearer token accepted by TokenAuthMiddleware for testUserID.
func authHeader() string {
	td, _ := shared.CreateToken(testUserID)
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

	sm.users.On("Registration", mock.AnythingOfType("*domain.User"), mock.AnythingOfType("*domain.Language")).
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

	sm.users.On("Login", mock.AnythingOfType("*domain.User")).
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

	sm.users.On("Refresh", mock.AnythingOfType("*domain.RefreshInput")).
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

	sm.users.On("Logout", mock.AnythingOfType("*domain.AccessDetails")).Return(nil)

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

	sm.users.On("GetUserIdFromToken", mock.Anything).Return(testUserID, nil)
	sm.categories.On("GetCategories", testUserID).Return([]domain.GetCategoryResponse{
		{Id: 1, Category: "Dates", Color: "#ffff60", IsLocked: true},
	}, nil)

	rec := doRequest(router, http.MethodGet, "/categories", "", authHeader())

	assert.Equal(t, http.StatusOK, rec.Code)
	var out []domain.GetCategoryResponse
	assert.NoError(t, json.Unmarshal(rec.Body.Bytes(), &out))
	assert.Len(t, out, 1)
	assert.Equal(t, "Dates", out[0].Category)
	sm.categories.AssertExpectations(t)
}

func TestCreateCategoryEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.users.On("GetUserIdFromToken", mock.Anything).Return(testUserID, nil)
	sm.categories.On("CreateCategory", mock.AnythingOfType("*domain.Category")).Return(nil)

	rec := doRequest(router, http.MethodPost, "/categories",
		`{"category":"Noces","color":"#ff0000"}`, authHeader())

	assert.Equal(t, http.StatusCreated, rec.Code)
	sm.categories.AssertExpectations(t)
}

func TestCreateCategoryRejectsNonHexColor(t *testing.T) {
	router, sm := newTestServer()
	sm.users.On("GetUserIdFromToken", mock.Anything).Return(testUserID, nil)

	rec := doRequest(router, http.MethodPost, "/categories",
		`{"category":"Noces","color":"red"}`, authHeader())

	assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
	sm.categories.AssertNotCalled(t, "CreateCategory", mock.Anything)
}

func TestUpdateCategoryEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.users.On("GetUserIdFromToken", mock.Anything).Return(testUserID, nil)
	sm.categories.On("UpdateCategory", mock.AnythingOfType("*domain.Category")).Return(nil)

	rec := doRequest(router, http.MethodPatch, "/categories/5",
		`{"category":"Autres","color":"#ff0000"}`, authHeader())

	assert.Equal(t, http.StatusNoContent, rec.Code)
	sm.categories.AssertExpectations(t)
}

func TestDeleteCategoryEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.users.On("GetUserIdFromToken", mock.Anything).Return(testUserID, nil)
	sm.categories.On("DeleteCategory", uint(5), testUserID, false).Return(nil)

	rec := doRequest(router, http.MethodDelete, "/categories/5", `{"moveTags":false}`, authHeader())

	assert.Equal(t, http.StatusNoContent, rec.Code)
	sm.categories.AssertExpectations(t)
}

/* ------------------------------- Events --------------------------------- */

func TestGetEventsEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.users.On("GetUserIdFromToken", mock.Anything).Return(testUserID, nil)
	sm.events.On("GetEvents", testUserID, mock.Anything).Return([]domain.GetEventsResponse{
		{Event: domain.Event{Id: 1, Description: "cool"}},
	}, nil)

	rec := doRequest(router, http.MethodGet, "/events", `{"tags":[]}`, authHeader())

	assert.Equal(t, http.StatusOK, rec.Code)
	var out []domain.GetEventsResponse
	assert.NoError(t, json.Unmarshal(rec.Body.Bytes(), &out))
	assert.Len(t, out, 1)
	sm.events.AssertExpectations(t)
}

func TestCreateEventEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.users.On("GetUserIdFromToken", mock.Anything).Return(testUserID, nil)
	sm.events.On("CreateEvent", testUserID, mock.AnythingOfType("*domain.Event"), mock.Anything).Return(nil)

	rec := doRequest(router, http.MethodPost, "/events",
		`{"description":"cool","date":"1993-12-01T00:00:00Z","tagsId":[1,2]}`, authHeader())

	assert.Equal(t, http.StatusCreated, rec.Code)
	sm.events.AssertExpectations(t)
}

func TestCreateEventRejectsMissingDate(t *testing.T) {
	router, sm := newTestServer()
	sm.users.On("GetUserIdFromToken", mock.Anything).Return(testUserID, nil)

	rec := doRequest(router, http.MethodPost, "/events", `{"tagsId":[1]}`, authHeader())

	assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
	sm.events.AssertNotCalled(t, "CreateEvent", mock.Anything, mock.Anything, mock.Anything)
}

func TestDeleteEventEndpoint(t *testing.T) {
	router, sm := newTestServer()

	sm.users.On("GetUserIdFromToken", mock.Anything).Return(testUserID, nil)
	sm.events.On("DeleteEvent", uint(9)).Return(nil)

	rec := doRequest(router, http.MethodDelete, "/events/9", "", authHeader())

	assert.Equal(t, http.StatusNoContent, rec.Code)
	sm.events.AssertExpectations(t)
}
