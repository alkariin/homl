package mocks

import (
	"github.com/stretchr/testify/mock"
)

// MockTagsRepo is a programmable testify mock for tag.Repository.
type MockTagsRepo struct {
	mock.Mock
}

func (m *MockTagsRepo) Create(tagNameEncrypt string, idCategory uint) error {
	ret := m.Called(tagNameEncrypt, idCategory)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockTagsRepo) Update(tagNameEncrypt string, idCategory uint, idTag uint) error {
	ret := m.Called(tagNameEncrypt, idCategory, idTag)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockTagsRepo) Delete(idTag uint, idUser uint64) error {
	ret := m.Called(idTag, idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockTagsRepo) FindTagIdByTagAndIdCategory(encMonth string, idCategoryDate uint) (uint, error) {
	ret := m.Called(encMonth, idCategoryDate)

	var r0 uint
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(uint)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}

func (m *MockTagsRepo) FindMainTagIdOfPerson(idPerson uint) (uint, error) {
	ret := m.Called(idPerson)

	var r0 uint
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(uint)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}
