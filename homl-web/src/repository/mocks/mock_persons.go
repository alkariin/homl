package mocks

import (
	"github.com/alkariin/homl/homl-web/model"
	"github.com/stretchr/testify/mock"
)

// MockPersonsRepo is a programmable testify mock for model.PersonsRepository.
type MockPersonsRepo struct {
	mock.Mock
}

func (m *MockPersonsRepo) FindById(idPerson uint) (*model.Person, error) {
	ret := m.Called(idPerson)

	var r0 *model.Person
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*model.Person)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}

func (m *MockPersonsRepo) FindPersonsWithTagsAndCategories(idUser uint64) (map[uint]model.Person, map[uint][]model.Nickname, error) {
	ret := m.Called(idUser)

	var r0 map[uint]model.Person
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(map[uint]model.Person)
	}

	var r1 map[uint][]model.Nickname
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(map[uint][]model.Nickname)
	}

	var r2 error
	if ret.Get(2) != nil {
		r2 = ret.Get(2).(error)
	}

	return r0, r1, r2
}

func (m *MockPersonsRepo) CreatePersonWithTags(encFirstname string, encLastname string, encMainTagName string, idCategoryPerson uint, nicknames []string) error {
	ret := m.Called(encFirstname, encLastname, encMainTagName, idCategoryPerson, nicknames)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockPersonsRepo) CheckPersonIdsWithTagsAndCategories(idUser uint64, idPerson uint) error {
	ret := m.Called(idUser, idPerson)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockPersonsRepo) UpdatePersonWithTags(
	storedPerson *model.Person,
	encFirstname string,
	encLastname string,
	encMainTagName string,
	mainPersonTagId uint,
	idCategoryPerson uint,
	idUser uint64,
	bodyNicknames []model.Nickname,
) error {
	ret := m.Called(storedPerson, encFirstname, encLastname, encMainTagName, mainPersonTagId, idCategoryPerson, idUser, bodyNicknames)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockPersonsRepo) DeletePerson(idPerson uint, idUser uint64) error {
	ret := m.Called(idPerson, idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}
