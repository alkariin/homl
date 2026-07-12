package mocks

import (
	"context"

	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/stretchr/testify/mock"
)

// MockCategoriesRepo is a programmable testify mock for category.Repository.
// The ctx argument is deliberately not forwarded to m.Called so expectations
// stay expressed on the business arguments only.
type MockCategoriesRepo struct {
	mock.Mock
}

func (m *MockCategoriesRepo) FindByIdForUser(ctx context.Context, id uint, idUser uint64) (*category.Category, error) {
	ret := m.Called(id, idUser)

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

func (m *MockCategoriesRepo) FindIdByKind(ctx context.Context, idUser uint64, kind category.Kind) (uint, error) {
	ret := m.Called(idUser, kind)

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

func (m *MockCategoriesRepo) CheckTagsBelongToUser(ctx context.Context, tagsId []uint, idUser uint64) error {
	ret := m.Called(tagsId, idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockCategoriesRepo) GetAllCategoriesWithTags(ctx context.Context, idUser uint64) (map[uint]category.Category, map[uint][]category.TagDTO, error) {
	ret := m.Called(idUser)

	var r0 map[uint]category.Category
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(map[uint]category.Category)
	}

	var r1 map[uint][]category.TagDTO
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(map[uint][]category.TagDTO)
	}

	var r2 error
	if ret.Get(2) != nil {
		r2 = ret.Get(2).(error)
	}

	return r0, r1, r2
}

func (m *MockCategoriesRepo) Create(ctx context.Context, category *category.Category) error {
	ret := m.Called(category)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockCategoriesRepo) Update(ctx context.Context, category *category.Category) error {
	ret := m.Called(category)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockCategoriesRepo) Delete(ctx context.Context, idCategory uint, idUser uint64, moveTags bool) error {
	ret := m.Called(idCategory, idUser, moveTags)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockCategoriesRepo) CreateTag(ctx context.Context, tagNameEncrypt string, idCategory uint, idParentTag *uint) (uint, error) {
	ret := m.Called(tagNameEncrypt, idCategory, idParentTag)

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

func (m *MockCategoriesRepo) UpdateTag(ctx context.Context, tagNameEncrypt string, idCategory uint, idTag uint, idParentTag *uint) error {
	ret := m.Called(tagNameEncrypt, idCategory, idTag, idParentTag)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockCategoriesRepo) DeleteTag(ctx context.Context, idTag uint, idUser uint64) error {
	ret := m.Called(idTag, idUser)

	var r0 error
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(error)
	}

	return r0
}

func (m *MockCategoriesRepo) FindTagIdByTagAndIdCategory(ctx context.Context, encTag string, idCategory uint) (uint, error) {
	ret := m.Called(encTag, idCategory)

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

func (m *MockCategoriesRepo) FindTagForUser(ctx context.Context, idTag uint, idUser uint64) (*category.Tag, error) {
	ret := m.Called(idTag, idUser)

	var r0 *category.Tag
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(*category.Tag)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}

func (m *MockCategoriesRepo) HasSynonyms(ctx context.Context, idTag uint) (bool, error) {
	ret := m.Called(idTag)

	var r0 bool
	if ret.Get(0) != nil {
		r0 = ret.Get(0).(bool)
	}

	var r1 error
	if ret.Get(1) != nil {
		r1 = ret.Get(1).(error)
	}

	return r0, r1
}
