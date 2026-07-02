package mocks

import (
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/tag"
	"github.com/stretchr/testify/mock"
)

// MockCategoriesRepo is a programmable testify mock for category.Repository.
type MockCategoriesRepo struct {
	mock.Mock
}

func (m *MockCategoriesRepo) FindById(id uint) (*category.Category, error) {
	ret := m.Called(id)

	var r0 *category.Category
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*category.Category)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}

func (m *MockCategoriesRepo) FindLastIdByIdUser(idUser uint64) (uint, error) {
	ret := m.Called(idUser)

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

func (m *MockCategoriesRepo) CheckLastIdByIdAndIdUser(idUser uint64, idCategory uint) error {
	ret := m.Called(idUser, idCategory)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockCategoriesRepo) GetAllCategoriesWithTags(idUser uint64) (map[uint]category.Category, map[uint][]tag.TagDTO, error) {
	ret := m.Called(idUser)

	var r0 map[uint]category.Category
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(map[uint]category.Category)
	}

	var r1 map[uint][]tag.TagDTO
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(map[uint][]tag.TagDTO)
	}

	var r2 error
	if ret.Get(2) != nil {
		r2 = ret.Get(2).(error)
	}

	return r0, r1, r2
}

func (m *MockCategoriesRepo) Create(category *category.Category) error {
	ret := m.Called(category)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockCategoriesRepo) Update(category *category.Category) error {
	ret := m.Called(category)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockCategoriesRepo) Delete(idCategory uint, idUser uint64, moveTags bool) error {
	ret := m.Called(idCategory, idUser, moveTags)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}
