// Package mocks provides programmable testify mocks for the application
// service interfaces and the domain repository interfaces. They are used by
// the HTTP integration tests (package web) and the application service tests
// to drive the real code without touching the database.
package mocks

import (
	"net/http"

	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
	"github.com/alkariin/homl/homl-web/internal/domain/person"
	"github.com/alkariin/homl/homl-web/internal/domain/settings"
	"github.com/alkariin/homl/homl-web/internal/domain/tag"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/stretchr/testify/mock"
)

func errAt(ret mock.Arguments, i int) error {
	if ret.Get(i) != nil {
		return ret.Get(i).(error)
	}
	return nil
}

func tokensAt(ret mock.Arguments, i int) map[string]string {
	if ret.Get(i) != nil {
		return ret.Get(i).(map[string]string)
	}
	return nil
}

/* ----------------------------- UsersService ----------------------------- */

type MockUsersService struct {
	mock.Mock
}

func (m *MockUsersService) Registration(user *user.User, language *settings.Language) (map[string]string, error) {
	ret := m.Called(user, language)
	return tokensAt(ret, 0), errAt(ret, 1)
}

func (m *MockUsersService) Login(user *user.User) (map[string]string, error) {
	ret := m.Called(user)
	return tokensAt(ret, 0), errAt(ret, 1)
}

func (m *MockUsersService) Logout(accessDetails *user.AccessDetails) error {
	return errAt(m.Called(accessDetails), 0)
}

func (m *MockUsersService) Refresh(refreshInput *user.RefreshInput) (map[string]string, error) {
	ret := m.Called(refreshInput)
	return tokensAt(ret, 0), errAt(ret, 1)
}

func (m *MockUsersService) ResetPassword(user *user.User) error {
	return errAt(m.Called(user), 0)
}

func (m *MockUsersService) ConfirmResetPassword(newPassword string, idUser uint64) (map[string]string, error) {
	ret := m.Called(newPassword, idUser)
	return tokensAt(ret, 0), errAt(ret, 1)
}

func (m *MockUsersService) UpdatePassword(oldPassword string, newPassword string, idUser uint64) (map[string]string, error) {
	ret := m.Called(oldPassword, newPassword, idUser)
	return tokensAt(ret, 0), errAt(ret, 1)
}

func (m *MockUsersService) Challenge(refreshToken string) (*string, error) {
	ret := m.Called(refreshToken)
	var r0 *string
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*string)
	}
	return r0, errAt(ret, 1)
}

func (m *MockUsersService) GetUserIdFromToken(request *http.Request) (uint64, error) {
	ret := m.Called(request)
	var r0 uint64
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(uint64)
	}
	return r0, errAt(ret, 1)
}

func (m *MockUsersService) SecureAuth(u *user.User) (*user.UserResponse, error) {
	ret := m.Called(u)
	var r0 *user.UserResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*user.UserResponse)
	}
	return r0, errAt(ret, 1)
}

/* --------------------------- CategoriesService --------------------------- */

type MockCategoriesService struct {
	mock.Mock
}

func (m *MockCategoriesService) GetCategories(idUser uint64) ([]category.GetCategoryResponse, error) {
	ret := m.Called(idUser)
	var r0 []category.GetCategoryResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).([]category.GetCategoryResponse)
	}
	return r0, errAt(ret, 1)
}

func (m *MockCategoriesService) CreateCategory(category *category.Category) error {
	return errAt(m.Called(category), 0)
}

func (m *MockCategoriesService) UpdateCategory(category *category.Category) error {
	return errAt(m.Called(category), 0)
}

func (m *MockCategoriesService) DeleteCategory(idCategory uint, idUser uint64, moveTags bool) error {
	return errAt(m.Called(idCategory, idUser, moveTags), 0)
}

/* ----------------------------- EventsService ----------------------------- */

type MockEventsService struct {
	mock.Mock
}

func (m *MockEventsService) GetEvents(idUser uint64, tags []string) ([]event.GetEventsResponse, error) {
	ret := m.Called(idUser, tags)
	var r0 []event.GetEventsResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).([]event.GetEventsResponse)
	}
	return r0, errAt(ret, 1)
}

func (m *MockEventsService) CreateEvent(idUser uint64, event *event.Event, tagsId []uint) error {
	return errAt(m.Called(idUser, event, tagsId), 0)
}

func (m *MockEventsService) UpdateEvent(idUser uint64, event *event.Event, tagsId []uint) error {
	return errAt(m.Called(idUser, event, tagsId), 0)
}

func (m *MockEventsService) DeleteEvent(idEvent uint) error {
	return errAt(m.Called(idEvent), 0)
}

/* ------------------------------ TagsService ------------------------------ */

type MockTagsService struct {
	mock.Mock
}

func (m *MockTagsService) CreateTag(idUser uint64, tag *tag.Tag) error {
	return errAt(m.Called(idUser, tag), 0)
}

func (m *MockTagsService) UpdateTag(idUser uint64, tag *tag.Tag) error {
	return errAt(m.Called(idUser, tag), 0)
}

func (m *MockTagsService) DeleteTag(idTag uint, idUser uint64) error {
	return errAt(m.Called(idTag, idUser), 0)
}

/* ----------------------------- PersonsService ---------------------------- */

type MockPersonsService struct {
	mock.Mock
}

func (m *MockPersonsService) GetPersons(idUser uint64) ([]person.GetPersonsResponse, error) {
	ret := m.Called(idUser)
	var r0 []person.GetPersonsResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).([]person.GetPersonsResponse)
	}
	return r0, errAt(ret, 1)
}

func (m *MockPersonsService) CreatePerson(person *person.Person, nicknames []string, idUser uint64) error {
	return errAt(m.Called(person, nicknames, idUser), 0)
}

func (m *MockPersonsService) UpdatePerson(person *person.Person, nicknames []person.Nickname, idUser uint64) error {
	return errAt(m.Called(person, nicknames, idUser), 0)
}

func (m *MockPersonsService) DeletePerson(idPerson uint, idUser uint64) error {
	return errAt(m.Called(idPerson, idUser), 0)
}

/* ---------------------------- SettingsService ---------------------------- */

type MockSettingsService struct {
	mock.Mock
}

func (m *MockSettingsService) GetSettings(idUser uint64) (*settings.SettingsResponse, error) {
	ret := m.Called(idUser)
	var r0 *settings.SettingsResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*settings.SettingsResponse)
	}
	return r0, errAt(ret, 1)
}

func (m *MockSettingsService) UpdateSettings(idUser uint64, newSettings *settings.Settings) (*settings.SettingsResponse, error) {
	ret := m.Called(idUser, newSettings)
	var r0 *settings.SettingsResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*settings.SettingsResponse)
	}
	return r0, errAt(ret, 1)
}
