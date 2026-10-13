package persistence

import (
	"context"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/homl/homl-web/internal/domain/user"
)

// The session store against an in-memory Redis: the rotation's replay window
// lives in key bookkeeping that mocked repositories cannot exercise.

const sessionUser = uint64(7)

func newSessionStore(t *testing.T) (*UsersRepository, *miniredis.Miniredis) {
	t.Helper()
	mr := miniredis.RunT(t)
	client := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	t.Cleanup(func() { _ = client.Close() })
	return &UsersRepository{Redis: client}, mr
}

func newPair() *user.TokenDetails {
	now := time.Now()
	return &user.TokenDetails{
		AccessToken:  "access",
		RefreshToken: "refresh",
		AccessUuid:   uuid.NewString(),
		RefreshUuid:  uuid.NewString(),
		AtExpires:    now.Add(10 * time.Minute).Unix(),
		RtExpires:    now.Add(24 * time.Hour).Unix(),
	}
}

// login stores a fresh pair, as a login does.
func login(t *testing.T, repo *UsersRepository) *user.TokenDetails {
	t.Helper()
	pair := newPair()
	require.NoError(t, repo.CreateAuth(context.Background(), sessionUser, pair))
	return pair
}

func rotate(t *testing.T, repo *UsersRepository, from string) (*user.TokenDetails, bool) {
	t.Helper()
	pair := newPair()
	ok, err := repo.RotateSession(context.Background(), sessionUser, from, pair)
	require.NoError(t, err)
	return pair, ok
}

func accessWorks(repo *UsersRepository, pair *user.TokenDetails) bool {
	_, err := repo.FetchAuth(context.Background(), &user.AccessDetails{AccessUuid: pair.AccessUuid})
	return err == nil
}

func usable(t *testing.T, repo *UsersRepository, refreshUuid string) bool {
	t.Helper()
	ok, err := repo.RefreshSessionExists(context.Background(), refreshUuid)
	require.NoError(t, err)
	return ok
}

func TestRotationRetiresThePresentedPair(t *testing.T) {
	repo, mr := newSessionStore(t)
	p0 := login(t, repo)

	p1, ok := rotate(t, repo, p0.RefreshUuid)

	require.True(t, ok)
	assert.False(t, accessWorks(repo, p0), "the old access token dies at once")
	assert.True(t, accessWorks(repo, p1))
	assert.False(t, mr.Exists(refreshKeyPrefix+p0.RefreshUuid))
	// Not used yet: the old refresh token may still replay the rotation, and
	// the second-factor prompt and /challenge accept it.
	assert.True(t, usable(t, repo, p0.RefreshUuid))
	assert.True(t, usable(t, repo, p1.RefreshUuid))
}

func TestReplayAfterALostAnswer(t *testing.T) {
	repo, mr := newSessionStore(t)
	p0 := login(t, repo)
	lost, ok := rotate(t, repo, p0.RefreshUuid)
	require.True(t, ok)

	// The client never got `lost` and tries again with the old token.
	p2, ok := rotate(t, repo, p0.RefreshUuid)

	require.True(t, ok)
	assert.True(t, accessWorks(repo, p2))
	assert.False(t, accessWorks(repo, lost), "the pair nobody received is revoked")
	assert.False(t, usable(t, repo, lost.RefreshUuid))
	assert.False(t, mr.Exists(prevKeyPrefix+lost.RefreshUuid))

	// Still unsettled: the answer may have been lost again.
	p3, ok := rotate(t, repo, p0.RefreshUuid)
	require.True(t, ok)
	assert.False(t, accessWorks(repo, p2))
	assert.True(t, accessWorks(repo, p3))
}

func TestUsingTheNewTokenSettlesTheRotation(t *testing.T) {
	repo, mr := newSessionStore(t)
	p0 := login(t, repo)
	p1, _ := rotate(t, repo, p0.RefreshUuid)

	p2, ok := rotate(t, repo, p1.RefreshUuid)

	require.True(t, ok)
	assert.False(t, usable(t, repo, p0.RefreshUuid), "p1 was received: p0 dies")
	assert.False(t, mr.Exists(rotatedKeyPrefix+p0.RefreshUuid))
	assert.False(t, mr.Exists(prevKeyPrefix+p1.RefreshUuid))

	// Reusing p0 now is refused and changes nothing.
	_, ok = rotate(t, repo, p0.RefreshUuid)
	assert.False(t, ok)
	assert.True(t, accessWorks(repo, p2))
	assert.True(t, usable(t, repo, p1.RefreshUuid), "p1 may replay its own rotation")
}

func TestLogoutTakesTheReplacedTokenAlong(t *testing.T) {
	repo, _ := newSessionStore(t)
	p0 := login(t, repo)
	p1, _ := rotate(t, repo, p0.RefreshUuid)

	deleted, err := repo.RevokeSessionByAccess(context.Background(), p1.AccessUuid)

	require.NoError(t, err)
	assert.Equal(t, int64(2), deleted)
	assert.False(t, usable(t, repo, p0.RefreshUuid),
		"a logged-out session must not come back through the token it replaced")
	_, ok := rotate(t, repo, p0.RefreshUuid)
	assert.False(t, ok)
}

func TestRevokeAllLeavesNoTokenAbleToReplay(t *testing.T) {
	repo, mr := newSessionStore(t)
	p0 := login(t, repo)
	p1, _ := rotate(t, repo, p0.RefreshUuid)
	other := login(t, repo)

	require.NoError(t, repo.RevokeAllSessions(context.Background(), sessionUser))

	for _, refreshUuid := range []string{p0.RefreshUuid, p1.RefreshUuid, other.RefreshUuid} {
		assert.False(t, usable(t, repo, refreshUuid))
		_, ok := rotate(t, repo, refreshUuid)
		assert.False(t, ok)
	}
	assert.Empty(t, mr.Keys(), "nothing of the user's sessions is left")
}

func TestRotationRefusesAnUnknownOrForeignToken(t *testing.T) {
	repo, _ := newSessionStore(t)
	p0 := login(t, repo)

	_, ok := rotate(t, repo, uuid.NewString())
	assert.False(t, ok)

	ok, err := repo.RotateSession(context.Background(), sessionUser+1, p0.RefreshUuid, newPair())
	require.NoError(t, err)
	assert.False(t, ok)
	assert.True(t, accessWorks(repo, p0), "a refused rotation changes nothing")
}

func TestTheReplayWindowLastsAsLongAsTheOldToken(t *testing.T) {
	repo, mr := newSessionStore(t)
	p0 := login(t, repo)
	remaining := mr.TTL(refreshKeyPrefix + p0.RefreshUuid)

	p1, _ := rotate(t, repo, p0.RefreshUuid)

	ttl := mr.TTL(rotatedKeyPrefix + p0.RefreshUuid)
	assert.InDelta(t, remaining.Seconds(), ttl.Seconds(), 2)
	assert.InDelta(t, remaining.Seconds(), mr.TTL(prevKeyPrefix+p1.RefreshUuid).Seconds(), 2)

	// Past the old token's own expiry, nothing can replay.
	mr.FastForward(remaining + time.Second)
	assert.False(t, usable(t, repo, p0.RefreshUuid))
}
