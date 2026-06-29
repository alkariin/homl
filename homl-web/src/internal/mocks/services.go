// Package mocks provides programmable testify mocks for the domain.*Service
// interfaces. They are used by the HTTP integration tests (package main) to
// drive the real Gin router without touching the database.
package mocks

import (
	"net/http"

	"github.com/alkariin/homl/homl-web/internal/domain"
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

func (m *MockUsersService) Registration(user *domain.User, language *domain.Language) (map[string]string, error) {
	ret := m.Called(user, language)
	return tokensAt(ret, 0), errAt(ret, 1)
}

func (m *MockUsersService) Login(user *domain.User) (map[string]string, error) {
	ret := m.Called(user)
	return tokensAt(ret, 0), errAt(ret, 1)
}

func (m *MockUsersService) Logout(accessDetails *domain.AccessDetails) error {
	return errAt(m.Called(accessDetails), 0)
}

func (m *MockUsersService) Refresh(refreshInput *domain.RefreshInput) (map[string]string, error) {
	ret := m.Called(refreshInput)
	return tokensAt(ret, 0), errAt(ret, 1)
}

func (m *MockUsersService) ResetPassword(user *domain.User) error {
	return errAt(m.Called(user), 0)
}

func (m *MockUsersService) ConfirmResetPassword(user *domain.User) (map[string]string, error) {
	ret := m.Called(user)
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

func (m *MockUsersService) SecureAuth(user *domain.User) (*domain.UserResponse, error) {
	ret := m.Called(user)
	var r0 *domain.UserResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*domain.UserResponse)
	}
	return r0, errAt(ret, 1)
}

/* --------------------------- CategoriesService --------------------------- */

type MockCategoriesService struct {
	mock.Mock
}

func (m *MockCategoriesService) GetCategories(idUser uint64) ([]domain.GetCategoryResponse, error) {
	ret := m.Called(idUser)
	var r0 []domain.GetCategoryResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).([]domain.GetCategoryResponse)
	}
	return r0, errAt(ret, 1)
}

func (m *MockCategoriesService) CreateCategory(category *domain.Category) error {
	return errAt(m.Called(category), 0)
}

func (m *MockCategoriesService) UpdateCategory(category *domain.Category) error {
	return errAt(m.Called(category), 0)
}

func (m *MockCategoriesService) DeleteCategory(idCategory uint, idUser uint64, moveTags bool) error {
	return errAt(m.Called(idCategory, idUser, moveTags), 0)
}

/* ----------------------------- EventsService ----------------------------- */

type MockEventsService struct {
	mock.Mock
}

func (m *MockEventsService) GetEvents(idUser uint64, tags []string) ([]domain.GetEventsResponse, error) {
	ret := m.Called(idUser, tags)
	var r0 []domain.GetEventsResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).([]domain.GetEventsResponse)
	}
	return r0, errAt(ret, 1)
}

func (m *MockEventsService) CreateEvent(idUser uint64, event *domain.Event, tagsId []uint) error {
	return errAt(m.Called(idUser, event, tagsId), 0)
}

func (m *MockEventsService) UpdateEvent(idUser uint64, event *domain.Event, tagsId []uint) error {
	return errAt(m.Called(idUser, event, tagsId), 0)
}

func (m *MockEventsService) DeleteEvent(idEvent uint) error {
	return errAt(m.Called(idEvent), 0)
}

/* ------------------------------ TagsService ------------------------------ */

type MockTagsService struct {
	mock.Mock
}

func (m *MockTagsService) CreateTag(idUser uint64, tag *domain.Tag) error {
	return errAt(m.Called(idUser, tag), 0)
}

func (m *MockTagsService) UpdateTag(idUser uint64, tag *domain.Tag) error {
	return errAt(m.Called(idUser, tag), 0)
}

func (m *MockTagsService) DeleteTag(idTag uint, idUser uint64) error {
	return errAt(m.Called(idTag, idUser), 0)
}

/* ----------------------------- PersonsService ---------------------------- */

type MockPersonsService struct {
	mock.Mock
}

func (m *MockPersonsService) GetPersons(idUser uint64) ([]domain.GetPersonsResponse, error) {
	ret := m.Called(idUser)
	var r0 []domain.GetPersonsResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).([]domain.GetPersonsResponse)
	}
	return r0, errAt(ret, 1)
}

func (m *MockPersonsService) CreatePerson(person *domain.Person, nicknames []string, idUser uint64) error {
	return errAt(m.Called(person, nicknames, idUser), 0)
}

func (m *MockPersonsService) UpdatePerson(person *domain.Person, nicknames []domain.Nickname, idUser uint64) error {
	return errAt(m.Called(person, nicknames, idUser), 0)
}

func (m *MockPersonsService) DeletePerson(idPerson uint, idUser uint64) error {
	return errAt(m.Called(idPerson, idUser), 0)
}

/* ---------------------------- SettingsService ---------------------------- */

type MockSettingsService struct {
	mock.Mock
}

func (m *MockSettingsService) GetSettings(idUser uint64) (*domain.SettingsResponse, error) {
	ret := m.Called(idUser)
	var r0 *domain.SettingsResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*domain.SettingsResponse)
	}
	return r0, errAt(ret, 1)
}

func (m *MockSettingsService) UpdateSettings(idUser uint64, settings *domain.Settings) (*domain.SettingsResponse, error) {
	ret := m.Called(idUser, settings)
	var r0 *domain.SettingsResponse
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*domain.SettingsResponse)
	}
	return r0, errAt(ret, 1)
}
