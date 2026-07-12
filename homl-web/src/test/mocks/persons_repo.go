package mocks

import (
	"context"

	"github.com/alkariin/homl/homl-web/internal/domain/person"
	"github.com/stretchr/testify/mock"
)

// MockPersonsRepo is a programmable testify mock for person.Repository.
// The ctx argument is deliberately not forwarded to m.Called so expectations
// stay expressed on the business arguments only.
type MockPersonsRepo struct {
	mock.Mock
}

func (m *MockPersonsRepo) FindById(ctx context.Context, idPerson uint) (*person.Person, error) {
	ret := m.Called(idPerson)

	var r0 *person.Person
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*person.Person)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}

func (m *MockPersonsRepo) FindAllByUser(ctx context.Context, idUser uint64) ([]person.Person, error) {
	ret := m.Called(idUser)

	var r0 []person.Person
	if ret.Get(0) != nil {
		r0 = ret.Get(0).([]person.Person)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}

func (m *MockPersonsRepo) CreatePersonWithMainTag(ctx context.Context, encFirstname string, encLastname string, encMainTagName string, idCategoryPerson uint) error {
	ret := m.Called(encFirstname, encLastname, encMainTagName, idCategoryPerson)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockPersonsRepo) CheckPersonIdsWithTagsAndCategories(ctx context.Context, idUser uint64, idPerson uint) error {
	ret := m.Called(idUser, idPerson)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockPersonsRepo) UpdatePersonWithMainTag(
	ctx context.Context,
	storedPerson *person.Person,
	encFirstname string,
	encLastname string,
	encMainTagName string,
	mainPersonTagId uint,
) error {
	ret := m.Called(storedPerson, encFirstname, encLastname, encMainTagName, mainPersonTagId)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockPersonsRepo) DeletePerson(ctx context.Context, idPerson uint, idUser uint64) error {
	ret := m.Called(idPerson, idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}
