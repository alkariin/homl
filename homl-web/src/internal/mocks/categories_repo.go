package mocks

import (
	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/stretchr/testify/mock"
)

// MockCategoriesRepo is a programmable testify mock for domain.CategoriesRepository.
type MockCategoriesRepo struct {
	mock.Mock
}

func (m *MockCategoriesRepo) FindById(id uint) (*domain.Category, error) {
	ret := m.Called(id)

	var r0 *domain.Category
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*domain.Category)
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

func (m *MockCategoriesRepo) GetAllCategoriesWithTags(idUser uint64) (map[uint]domain.Category, map[uint][]domain.TagDTO, error) {
	ret := m.Called(idUser)

	var r0 map[uint]domain.Category
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(map[uint]domain.Category)
	}

	var r1 map[uint][]domain.TagDTO
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(map[uint][]domain.TagDTO)
	}

	var r2 error
	if ret.Get(2) != nil {
		r2 = ret.Get(2).(error)
	}

	return r0, r1, r2
}

func (m *MockCategoriesRepo) Create(category *domain.Category) error {
	ret := m.Called(category)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockCategoriesRepo) Update(category *domain.Category) error {
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
