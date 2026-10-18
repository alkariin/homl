package persistence

import (
	"context"
	"strconv"
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
	ok, err := repo.RotateSession(context.Background(), sessionUser, from, pair, user.SessionInfo{})
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

	ok, err := repo.RotateSession(context.Background(), sessionUser+1, p0.RefreshUuid, newPair(), user.SessionInfo{})
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

/* ---------------------------- Device sessions ---------------------------- */

// open stores a fresh pair and opens its device session, as a login does.
func open(t *testing.T, repo *UsersRepository, userID uint64, info user.SessionInfo) *user.TokenDetails {
	t.Helper()
	pair := newPair()
	require.NoError(t, repo.CreateAuth(context.Background(), userID, pair))
	require.NoError(t, repo.OpenSession(context.Background(), userID, pair, info))
	return pair
}

func sessionsOf(t *testing.T, repo *UsersRepository, userID uint64) []user.Session {
	t.Helper()
	sessions, err := repo.ListSessions(context.Background(), userID)
	require.NoError(t, err)
	return sessions
}

func sessionOf(t *testing.T, repo *UsersRepository, pair *user.TokenDetails) string {
	t.Helper()
	id, err := repo.SessionOfAccess(context.Background(), pair.AccessUuid)
	require.NoError(t, err)
	return id
}

func rotateWith(t *testing.T, repo *UsersRepository, from string, info user.SessionInfo) *user.TokenDetails {
	t.Helper()
	pair := newPair()
	ok, err := repo.RotateSession(context.Background(), sessionUser, from, pair, info)
	require.NoError(t, err)
	require.True(t, ok)
	return pair
}

func TestALoginOpensADeviceSession(t *testing.T) {
	repo, _ := newSessionStore(t)
	p0 := open(t, repo, sessionUser, user.SessionInfo{Client: "android 0.5.0", IP: "10.0.0.2"})

	sessions := sessionsOf(t, repo, sessionUser)

	require.Len(t, sessions, 1)
	session := sessions[0]
	assert.Equal(t, "android 0.5.0", session.Client)
	assert.Equal(t, "10.0.0.2", session.IP)
	require.NotNil(t, session.CreatedAt)
	assert.WithinDuration(t, time.Now(), session.LastSeenAt, 2*time.Second)
	assert.Equal(t, session.Id, sessionOf(t, repo, p0))
}

func TestARefreshCarriesTheDeviceSession(t *testing.T) {
	repo, _ := newSessionStore(t)
	p0 := open(t, repo, sessionUser, user.SessionInfo{Client: "android 0.5.0", IP: "10.0.0.2"})
	before := sessionsOf(t, repo, sessionUser)[0]

	// An app that does not say what it is keeps the name it had.
	p1 := rotateWith(t, repo, p0.RefreshUuid, user.SessionInfo{IP: "192.0.2.7"})

	sessions := sessionsOf(t, repo, sessionUser)
	require.Len(t, sessions, 1)
	assert.Equal(t, before.Id, sessions[0].Id)
	assert.Equal(t, "android 0.5.0", sessions[0].Client)
	assert.Equal(t, "192.0.2.7", sessions[0].IP)
	assert.Equal(t, before.CreatedAt, sessions[0].CreatedAt)
	assert.Equal(t, before.Id, sessionOf(t, repo, p1))
}

func TestASessionFromBeforeIsTakenInAtItsFirstRefresh(t *testing.T) {
	repo, _ := newSessionStore(t)
	p0 := login(t, repo)
	assert.Empty(t, sessionsOf(t, repo, sessionUser))

	p1 := rotateWith(t, repo, p0.RefreshUuid, user.SessionInfo{Client: "web 0.5.0"})

	sessions := sessionsOf(t, repo, sessionUser)
	require.Len(t, sessions, 1)
	assert.Nil(t, sessions[0].CreatedAt, "its login time is unknown")
	assert.Equal(t, "web 0.5.0", sessions[0].Client)
	assert.Equal(t, sessions[0].Id, sessionOf(t, repo, p1))
}

func TestAReplayKeepsOneDeviceSession(t *testing.T) {
	repo, _ := newSessionStore(t)
	p0 := open(t, repo, sessionUser, user.SessionInfo{Client: "android 0.5.0"})
	id := sessionOf(t, repo, p0)
	// The answer to this rotation is lost: the client replays it with p0.
	rotateWith(t, repo, p0.RefreshUuid, user.SessionInfo{})
	p2 := rotateWith(t, repo, p0.RefreshUuid, user.SessionInfo{})

	sessions := sessionsOf(t, repo, sessionUser)
	require.Len(t, sessions, 1)
	assert.Equal(t, id, sessions[0].Id)
	assert.Equal(t, id, sessionOf(t, repo, p2))

	// Using the new token settles the rotation: p0 no longer points anywhere.
	rotateWith(t, repo, p2.RefreshUuid, user.SessionInfo{})
	assert.Len(t, sessionsOf(t, repo, sessionUser), 1)
}

func TestRevokingASessionSignsThatDeviceOutOnly(t *testing.T) {
	repo, _ := newSessionStore(t)
	phone := open(t, repo, sessionUser, user.SessionInfo{Client: "android 0.5.0"})
	laptop := open(t, repo, sessionUser, user.SessionInfo{Client: "web 0.5.0"})
	id := sessionOf(t, repo, phone)

	ok, err := repo.RevokeSession(context.Background(), sessionUser, id)

	require.NoError(t, err)
	assert.True(t, ok)
	assert.False(t, accessWorks(repo, phone))
	assert.False(t, usable(t, repo, phone.RefreshUuid))
	assert.True(t, accessWorks(repo, laptop))
	sessions := sessionsOf(t, repo, sessionUser)
	require.Len(t, sessions, 1)
	assert.Equal(t, "web 0.5.0", sessions[0].Client)
}

func TestRevokingASessionTakesAPendingRotationAlong(t *testing.T) {
	repo, _ := newSessionStore(t)
	p0 := open(t, repo, sessionUser, user.SessionInfo{})
	p1 := rotateWith(t, repo, p0.RefreshUuid, user.SessionInfo{})

	ok, err := repo.RevokeSession(context.Background(), sessionUser, sessionOf(t, repo, p1))

	require.NoError(t, err)
	assert.True(t, ok)
	assert.False(t, usable(t, repo, p1.RefreshUuid))
	assert.False(t, usable(t, repo, p0.RefreshUuid), "the replaced token cannot replay")
}

func TestAnotherUsersSessionCannotBeRevoked(t *testing.T) {
	repo, _ := newSessionStore(t)
	p0 := open(t, repo, sessionUser, user.SessionInfo{})

	ok, err := repo.RevokeSession(context.Background(), sessionUser+1, sessionOf(t, repo, p0))

	require.NoError(t, err)
	assert.False(t, ok)
	assert.True(t, accessWorks(repo, p0))

	ok, err = repo.RevokeSession(context.Background(), sessionUser, uuid.NewString())
	require.NoError(t, err)
	assert.False(t, ok)
}

func TestALogoutForgetsTheDeviceSession(t *testing.T) {
	repo, mr := newSessionStore(t)
	p0 := open(t, repo, sessionUser, user.SessionInfo{})
	id := sessionOf(t, repo, p0)

	_, err := repo.RevokeSessionByAccess(context.Background(), p0.AccessUuid)

	require.NoError(t, err)
	assert.Empty(t, sessionsOf(t, repo, sessionUser))
	assert.False(t, mr.Exists(deviceSessionPrefix+id))
	assert.False(t, mr.Exists(sessionOfPrefix+p0.RefreshUuid))
}

func TestRevokeAllForgetsEveryDeviceSession(t *testing.T) {
	repo, mr := newSessionStore(t)
	p0 := open(t, repo, sessionUser, user.SessionInfo{})
	open(t, repo, sessionUser, user.SessionInfo{})
	rotateWith(t, repo, p0.RefreshUuid, user.SessionInfo{})

	require.NoError(t, repo.RevokeAllSessions(context.Background(), sessionUser))

	assert.Empty(t, sessionsOf(t, repo, sessionUser))
	for _, key := range mr.Keys() {
		assert.NotContains(t, key, "auth:", "nothing of the user's sessions is left")
	}
}

func TestListingForgetsASessionWhoseTokensAreGone(t *testing.T) {
	repo, mr := newSessionStore(t)
	p0 := open(t, repo, sessionUser, user.SessionInfo{})
	id := sessionOf(t, repo, p0)
	// Expired, or deleted by hand: the refresh token is gone.
	mr.Del(refreshKeyPrefix + p0.RefreshUuid)

	assert.Empty(t, sessionsOf(t, repo, sessionUser))
	assert.False(t, mr.Exists(deviceSessionPrefix+id))
}

func TestSessionsAreListedMostRecentFirst(t *testing.T) {
	repo, mr := newSessionStore(t)
	older := open(t, repo, sessionUser, user.SessionInfo{Client: "older"})
	open(t, repo, sessionUser, user.SessionInfo{Client: "newer"})
	// Last seen an hour ago.
	mr.HSet(deviceSessionPrefix+sessionOf(t, repo, older), "seen",
		strconv.FormatInt(time.Now().Add(-time.Hour).Unix(), 10))

	sessions := sessionsOf(t, repo, sessionUser)

	require.Len(t, sessions, 2)
	assert.Equal(t, "newer", sessions[0].Client)
}
