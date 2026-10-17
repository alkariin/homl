//go:build dbtest

package dbtest

import (
	"context"
	"net/http"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/category"
	"github.com/alkariin/homl/homl-web/internal/domain/e2ee"
	"github.com/alkariin/homl/homl-web/internal/infrastructure/persistence"
)

// groupsOf returns the user's groups of one category, as GET /categories
// hands them out.
func groupsOf(t *testing.T, r *repos, idUser uint64, idCategory uint) []category.TagGroupDTO {
	t.Helper()
	groups, err := r.cats.GetAllTagGroups(context.Background(), idUser)
	require.NoError(t, err)
	return groups[idCategory]
}

// groupFixture is a person category holding three main tags and a synonym,
// and a "Family" group of Alice and Bob.
type groupFixture struct {
	user                   uint64
	persons                uint
	alice, bob, carol, ali uint
	family                 uint
}

func newGroupFixture(t *testing.T, r *repos) *groupFixture {
	t.Helper()
	ctx := context.Background()

	f := &groupFixture{user: newUser(t, r)}
	var err error
	f.persons, err = r.cats.FindIdByKind(ctx, f.user, category.KindPerson)
	require.NoError(t, err)

	f.alice, err = r.cats.CreateTag(ctx, r.enc(t, "Alice", f.user), nil, f.persons, nil)
	require.NoError(t, err)
	f.bob, err = r.cats.CreateTag(ctx, r.enc(t, "Bob", f.user), nil, f.persons, nil)
	require.NoError(t, err)
	f.carol, err = r.cats.CreateTag(ctx, r.enc(t, "Carol", f.user), nil, f.persons, nil)
	require.NoError(t, err)
	f.ali, err = r.cats.CreateTag(ctx, r.enc(t, "Ali", f.user), nil, f.persons, &f.alice)
	require.NoError(t, err)

	f.family, err = r.cats.CreateTagGroup(ctx, r.enc(t, "Family", f.user), nil, f.persons, []uint{f.alice, f.bob})
	require.NoError(t, err)
	return f
}

func TestTagGroupCrud(t *testing.T) {
	r := setup(t)
	ctx := context.Background()
	f := newGroupFixture(t, r)

	t.Run("the categories payload carries the group, name decrypted", func(t *testing.T) {
		groups := groupsOf(t, r, f.user, f.persons)
		require.Len(t, groups, 1)
		assert.Equal(t, "Family", groups[0].Name)
		assert.Equal(t, []uint{f.alice, f.bob}, groups[0].Members)
	})

	t.Run("a second group of the same name in the category conflicts", func(t *testing.T) {
		_, err := r.cats.CreateTagGroup(ctx, r.enc(t, "Family", f.user), nil, f.persons, []uint{f.carol})
		require.Error(t, err)
		assert.Equal(t, http.StatusConflict, apperror.Status(err))
		assert.Len(t, groupsOf(t, r, f.user, f.persons), 1, "nothing written")
	})

	t.Run("the same name in another category is fine", func(t *testing.T) {
		other := newCustomCategory(t, r, f.user, r.enc(t, "Friends", f.user))
		dave, err := r.cats.CreateTag(ctx, r.enc(t, "Dave", f.user), nil, other, nil)
		require.NoError(t, err)

		_, err = r.cats.CreateTagGroup(ctx, r.enc(t, "Family", f.user), nil, other, []uint{dave})
		assert.NoError(t, err)
	})

	t.Run("an update replaces the name and the members, a replay is a no-op", func(t *testing.T) {
		for i := 0; i < 2; i++ {
			require.NoError(t, r.cats.UpdateTagGroup(ctx, r.enc(t, "Close Family", f.user), nil, f.family, []uint{f.bob, f.carol}))
		}

		groups := groupsOf(t, r, f.user, f.persons)
		require.Len(t, groups, 1)
		assert.Equal(t, "Close Family", groups[0].Name)
		assert.Equal(t, []uint{f.bob, f.carol}, groups[0].Members)
	})

	t.Run("another user's group is out of reach", func(t *testing.T) {
		mallory := newUser(t, r)

		_, err := r.cats.FindTagGroupForUser(ctx, f.family, mallory)
		assert.Error(t, err)

		err = r.cats.DeleteTagGroup(ctx, f.family, mallory)
		assert.Equal(t, http.StatusNotFound, apperror.Status(err))
		assert.Len(t, groupsOf(t, r, f.user, f.persons), 1, "the group survives")
	})

	t.Run("deleting a group keeps its tags", func(t *testing.T) {
		require.NoError(t, r.cats.DeleteTagGroup(ctx, f.family, f.user))

		assert.Empty(t, groupsOf(t, r, f.user, f.persons))
		assert.True(t, tagExists(t, r, f.bob))
		assert.True(t, tagExists(t, r, f.carol))
	})
}

func TestCheckMainTagsInCategory(t *testing.T) {
	r := setup(t)
	ctx := context.Background()
	f := newGroupFixture(t, r)

	other, err := r.cats.FindIdByKind(ctx, f.user, category.KindOther)
	require.NoError(t, err)
	trip, err := r.cats.CreateTag(ctx, r.enc(t, "Trip", f.user), nil, other, nil)
	require.NoError(t, err)

	mallory := newUser(t, r)
	malloryPersons, err := r.cats.FindIdByKind(ctx, mallory, category.KindPerson)
	require.NoError(t, err)
	stranger, err := r.cats.CreateTag(ctx, r.enc(t, "Stranger", mallory), nil, malloryPersons, nil)
	require.NoError(t, err)

	assert.NoError(t, r.cats.CheckMainTagsInCategory(ctx, []uint{f.alice, f.bob, f.alice}, f.persons, f.user))
	assert.Error(t, r.cats.CheckMainTagsInCategory(ctx, []uint{f.alice, f.ali}, f.persons, f.user), "a synonym")
	assert.Error(t, r.cats.CheckMainTagsInCategory(ctx, []uint{f.alice, trip}, f.persons, f.user), "another category")
	assert.Error(t, r.cats.CheckMainTagsInCategory(ctx, []uint{stranger}, malloryPersons, f.user), "another user's")
	assert.Error(t, r.cats.CheckMainTagsInCategory(ctx, []uint{f.alice, 999999999}, f.persons, f.user), "an unknown id")
}

func TestTagGroupFollowsItsTags(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	t.Run("a deleted member leaves the group, which stays", func(t *testing.T) {
		f := newGroupFixture(t, r)

		require.NoError(t, r.cats.DeleteTag(ctx, f.bob, f.user, false))

		groups := groupsOf(t, r, f.user, f.persons)
		require.Len(t, groups, 1)
		assert.Equal(t, []uint{f.alice}, groups[0].Members)

		require.NoError(t, r.cats.DeleteTag(ctx, f.alice, f.user, false))
		groups = groupsOf(t, r, f.user, f.persons)
		require.Len(t, groups, 1, "an emptied group stays")
		assert.Equal(t, []uint{}, groups[0].Members)
	})

	t.Run("a member moved to another category leaves the group", func(t *testing.T) {
		f := newGroupFixture(t, r)
		other, err := r.cats.FindIdByKind(ctx, f.user, category.KindOther)
		require.NoError(t, err)

		require.NoError(t, r.cats.UpdateTag(ctx, r.enc(t, "Bob", f.user), nil, other, f.bob, nil))

		assert.Equal(t, []uint{f.alice}, groupsOf(t, r, f.user, f.persons)[0].Members)
	})

	t.Run("a renamed member stays", func(t *testing.T) {
		f := newGroupFixture(t, r)

		require.NoError(t, r.cats.UpdateTag(ctx, r.enc(t, "Bobby", f.user), nil, f.persons, f.bob, nil))

		assert.Equal(t, []uint{f.alice, f.bob}, groupsOf(t, r, f.user, f.persons)[0].Members)
	})

	t.Run("a member turned synonym hands its place to its main tag", func(t *testing.T) {
		f := newGroupFixture(t, r)

		// Bob becomes a synonym of Carol: Carol joins the group instead.
		require.NoError(t, r.cats.UpdateTag(ctx, r.enc(t, "Bob", f.user), nil, f.persons, f.bob, &f.carol))

		assert.Equal(t, []uint{f.alice, f.carol}, groupsOf(t, r, f.user, f.persons)[0].Members)
	})

	t.Run("a member turned synonym of another member leaves no duplicate", func(t *testing.T) {
		f := newGroupFixture(t, r)

		require.NoError(t, r.cats.UpdateTag(ctx, r.enc(t, "Bob", f.user), nil, f.persons, f.bob, &f.alice))

		assert.Equal(t, []uint{f.alice}, groupsOf(t, r, f.user, f.persons)[0].Members)
	})

	t.Run("a member turned synonym of a tag of another category leaves the group", func(t *testing.T) {
		f := newGroupFixture(t, r)
		other, err := r.cats.FindIdByKind(ctx, f.user, category.KindOther)
		require.NoError(t, err)
		trip, err := r.cats.CreateTag(ctx, r.enc(t, "Trip", f.user), nil, other, nil)
		require.NoError(t, err)

		require.NoError(t, r.cats.UpdateTag(ctx, r.enc(t, "Bob", f.user), nil, other, f.bob, &trip))

		assert.Equal(t, []uint{f.alice}, groupsOf(t, r, f.user, f.persons)[0].Members)
		assert.Empty(t, groupsOf(t, r, f.user, other), "the main tag joins no group")
	})
}

func TestTagGroupCategoryDelete(t *testing.T) {
	r := setup(t)
	ctx := context.Background()

	t.Run("moving the tags to Others takes the groups along", func(t *testing.T) {
		f := newGroupFixture(t, r)
		other, err := r.cats.FindIdByKind(ctx, f.user, category.KindOther)
		require.NoError(t, err)

		require.NoError(t, r.cats.Delete(ctx, f.persons, f.user, true, false))

		groups := groupsOf(t, r, f.user, other)
		require.Len(t, groups, 1)
		assert.Equal(t, "Family", groups[0].Name)
		assert.Equal(t, []uint{f.alice, f.bob}, groups[0].Members)
	})

	t.Run("a group name taken in Others refuses the move", func(t *testing.T) {
		f := newGroupFixture(t, r)
		other, err := r.cats.FindIdByKind(ctx, f.user, category.KindOther)
		require.NoError(t, err)
		trip, err := r.cats.CreateTag(ctx, r.enc(t, "Trip", f.user), nil, other, nil)
		require.NoError(t, err)
		_, err = r.cats.CreateTagGroup(ctx, r.enc(t, "Family", f.user), nil, other, []uint{trip})
		require.NoError(t, err)

		err = r.cats.Delete(ctx, f.persons, f.user, true, false)
		var appErr *apperror.Error
		require.ErrorAs(t, err, &appErr)
		assert.Equal(t, apperror.CodeTagNameConflict, appErr.Code)
		assert.True(t, categoryExists(t, r, f.persons), "nothing deleted")
		assert.Len(t, groupsOf(t, r, f.user, f.persons), 1, "nothing moved")
	})

	t.Run("deleting the tags deletes the groups", func(t *testing.T) {
		f := newGroupFixture(t, r)

		require.NoError(t, r.cats.Delete(ctx, f.persons, f.user, false, false))

		var n int
		require.NoError(t, r.db.Get(&n, "SELECT COUNT(*) FROM TagGroups WHERE id = ?", f.family))
		assert.Zero(t, n)
	})
}

func TestTagGroupE2EEMigrate(t *testing.T) {
	r := setup(t)
	ctx := context.Background()
	e2eeRepo := persistence.NewE2EERepository(r.db, r.aes)
	f := newGroupFixture(t, r)
	keyCheck := strings.Repeat("cd", 32)

	data := fetchAll(t, r, e2eeRepo, f.user)
	for i := range data.Categories {
		data.Categories[i].Category = blob(byte(i))
	}
	for i := range data.Tags {
		idx := index("t" + string(rune('a'+i)))
		data.Tags[i].Tag = blob(byte(0x10 + i))
		data.Tags[i].TagIndex = &idx
	}
	require.Len(t, data.TagGroups, 1)
	groupIdx := index("ff")
	data.TagGroups[0].Name = blob(0x30)
	data.TagGroups[0].NameIndex = &groupIdx

	t.Run("enable conflicts when the groups are missing from the payload", func(t *testing.T) {
		short := *data
		short.TagGroups = nil
		err := e2eeRepo.Migrate(ctx, f.user, true, &keyCheck, &short)
		assert.Equal(t, http.StatusConflict, apperror.Status(err))
	})

	t.Run("enable stores the group blob and its index", func(t *testing.T) {
		require.NoError(t, e2eeRepo.Migrate(ctx, f.user, true, &keyCheck, data))

		var name string
		var nameIndex *string
		require.NoError(t, r.db.QueryRowContext(ctx, "SELECT name, nameIndex FROM TagGroups WHERE id = ?", f.family).Scan(&name, &nameIndex))
		assert.Equal(t, blob(0x30), name)
		require.NotNil(t, nameIndex)
		assert.Equal(t, groupIdx, *nameIndex)

		// The payload hands the blob back verbatim.
		groups, err := r.cats.GetAllTagGroups(e2ee.WithEnabled(ctx, true), f.user)
		require.NoError(t, err)
		assert.Equal(t, blob(0x30), groups[f.persons][0].Name)
	})

	t.Run("disable re-encrypts the name at rest and clears the index", func(t *testing.T) {
		back := fetchAll(t, r, e2eeRepo, f.user)
		for i := range back.Categories {
			back.Categories[i].Category = "Category " + strings.Repeat("x", i+1)
		}
		for i := range back.Tags {
			back.Tags[i].Tag = "Tag " + strings.Repeat("y", i+1)
		}
		back.TagGroups[0].Name = "Family"

		require.NoError(t, e2eeRepo.Migrate(ctx, f.user, false, nil, back))

		groups := groupsOf(t, r, f.user, f.persons)
		require.Len(t, groups, 1)
		assert.Equal(t, "Family", groups[0].Name)
		var nameIndex *string
		require.NoError(t, r.db.GetContext(ctx, &nameIndex, "SELECT nameIndex FROM TagGroups WHERE id = ?", f.family))
		assert.Nil(t, nameIndex)
	})
}
