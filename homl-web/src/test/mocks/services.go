// Package mocks provides programmable testify mocks for the application
// service interfaces and the domain repository interfaces. They are used by
// the HTTP integration tests (package web) and the application service tests
// to drive the real code without touching the database.
package mocks

import (
	"context"
	"net/http"

	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/event"
	"github.com/alkariin/homl/homl-web/internal/domain/person"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/stretchr/testify/mock"
)

// The ctx argument of the service methods is deliberately not forwarded to
// m.Called so expectations stay expressed on the business arguments only.

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

func (m *MockUsersService) Registration(ctx context.Context, u *user.User, language *user.Language) (map[string]string, error) {
	ret := m.Called(u, language)
	return tokensAt(ret, 0), errAt(ret, 1)
}

func (m *MockUsersService) Login(ctx context.Context, user *user.User) (map[string]string, error) {
	ret := m.Called(user)
	return tokensAt(ret, 0), errAt(ret, 1)
}

func (m *MockUsersService) Logout(ctx context.Context, accessDetails *user.AccessDetails) error {
	return errAt(m.Called(accessDetails), 0)
}

func (m *MockUsersService) Refresh(ctx context.Context, refreshInput *user.RefreshInput) (map[string]string, error) {
	ret := m.Called(refreshInput)
	return tokensAt(ret, 0), errAt(ret, 1)
}

func (m *MockUsersService) ResetPassword(ctx context.Context, user *user.User) error {
	return errAt(m.Called(user), 0)
}

func (m *MockUsersService) ConfirmResetPassword(ctx context.Context, newPassword string, resetToken string) (map[string]string, error) {
	ret := m.Called(newPassword, resetToken)
	return tokensAt(ret, 0), errAt(ret, 1)
}

func (m *MockUsersService) UpdatePassword(ctx context.Context, oldPassword string, newPassword string, idUser uint64) (map[string]string, error) {
	ret := m.Called(oldPassword, newPassword, idUser)
	return tokensAt(ret, 0), errAt(ret, 1)
}

func (m *MockUsersService) Challenge(ctx context.Context, refreshToken string) (*string, error) {
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

func (m *MockUsersService) SecureAuth(ctx context.Context, u *user.User) (*user.UserResponse, error) {
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

func (m *MockCategoriesService) GetCategories(ctx context.Context, idUser uint64) ([]category.GetCategoryResponse, error) {
	ret := m.Called(idUser)
	var r0 []category.GetCategoryResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).([]category.GetCategoryResponse)
	}
	return r0, errAt(ret, 1)
}

func (m *MockCategoriesService) CreateCategory(ctx context.Context, category *category.Category) error {
	return errAt(m.Called(category), 0)
}

func (m *MockCategoriesService) UpdateCategory(ctx context.Context, category *category.Category) error {
	return errAt(m.Called(category), 0)
}

func (m *MockCategoriesService) DeleteCategory(ctx context.Context, idCategory uint, idUser uint64, moveTags bool) error {
	return errAt(m.Called(idCategory, idUser, moveTags), 0)
}

/* ----------------------------- EventsService ----------------------------- */

type MockEventsService struct {
	mock.Mock
}

func (m *MockEventsService) GetEvents(ctx context.Context, idUser uint64, tags []string) ([]event.GetEventsResponse, error) {
	ret := m.Called(idUser, tags)
	var r0 []event.GetEventsResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).([]event.GetEventsResponse)
	}
	return r0, errAt(ret, 1)
}

func (m *MockEventsService) CreateEvent(ctx context.Context, idUser uint64, event *event.Event, tagsId []uint) error {
	return errAt(m.Called(idUser, event, tagsId), 0)
}

func (m *MockEventsService) UpdateEvent(ctx context.Context, idUser uint64, event *event.Event, tagsId []uint) error {
	return errAt(m.Called(idUser, event, tagsId), 0)
}

func (m *MockEventsService) DeleteEvent(ctx context.Context, idEvent uint, idUser uint64) error {
	return errAt(m.Called(idEvent, idUser), 0)
}

/* ------------------------------ TagsService ------------------------------ */

type MockTagsService struct {
	mock.Mock
}

func (m *MockTagsService) CreateTag(ctx context.Context, idUser uint64, tag *category.Tag) (uint, error) {
	ret := m.Called(idUser, tag)
	var r0 uint
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(uint)
	}
	return r0, errAt(ret, 1)
}

func (m *MockTagsService) UpdateTag(ctx context.Context, idUser uint64, tag *category.Tag) error {
	return errAt(m.Called(idUser, tag), 0)
}

func (m *MockTagsService) DeleteTag(ctx context.Context, idTag uint, idUser uint64) error {
	return errAt(m.Called(idTag, idUser), 0)
}

/* ----------------------------- PersonsService ---------------------------- */

type MockPersonsService struct {
	mock.Mock
}

func (m *MockPersonsService) GetPersons(ctx context.Context, idUser uint64) ([]person.GetPersonsResponse, error) {
	ret := m.Called(idUser)
	var r0 []person.GetPersonsResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).([]person.GetPersonsResponse)
	}
	return r0, errAt(ret, 1)
}

func (m *MockPersonsService) CreatePerson(ctx context.Context, person *person.Person, nicknames []string, idUser uint64) error {
	return errAt(m.Called(person, nicknames, idUser), 0)
}

func (m *MockPersonsService) UpdatePerson(ctx context.Context, person *person.Person, nicknames []person.Nickname, idUser uint64) error {
	return errAt(m.Called(person, nicknames, idUser), 0)
}

func (m *MockPersonsService) DeletePerson(ctx context.Context, idPerson uint, idUser uint64) error {
	return errAt(m.Called(idPerson, idUser), 0)
}

/* ---------------------------- SettingsService ---------------------------- */

type MockSettingsService struct {
	mock.Mock
}

func (m *MockSettingsService) GetSettings(ctx context.Context, idUser uint64) (*user.SettingsResponse, error) {
	ret := m.Called(idUser)
	var r0 *user.SettingsResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*user.SettingsResponse)
	}
	return r0, errAt(ret, 1)
}

func (m *MockSettingsService) UpdateSettings(ctx context.Context, idUser uint64, newSettings *user.Settings) (*user.SettingsResponse, error) {
	ret := m.Called(idUser, newSettings)
	var r0 *user.SettingsResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*user.SettingsResponse)
	}
	return r0, errAt(ret, 1)
}
