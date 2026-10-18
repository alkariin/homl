package persistence

import (
	"context"
	"sort"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	"github.com/alkariin/homl/homl-web/internal/domain/user"
)

// A device session spans a login and every rotation after it: the tokens
// change at each refresh, the session id does not (docs/auth-flows.md,
// "Signed-in devices"). In Redis:
//
//   - deviceSessionPrefix+id is a hash: user, refresh (the uuid of the newest
//     refresh token handed out), created (unix seconds, missing for a session
//     taken in at its first refresh after devices started being recorded),
//     seen (the last login or refresh), client, ip;
//   - sessionOfPrefix+refresh uuid points a refresh token at its session;
//   - userDevicesPrefix+user id is the set of the user's session ids.
//
// They all live as long as the newest refresh token.
const (
	deviceSessionPrefix = "auth:device:"
	sessionOfPrefix     = "auth:sid:"
	userDevicesPrefix   = "auth:devices:"
)

// OpenSession records a new device session around the pair td.
func (u *UsersRepository) OpenSession(ctx context.Context, userID uint64, td *user.TokenDetails, info user.SessionInfo) error {
	return u.writeSession(ctx, userID, uuid.NewString(), td, info, true)
}

// carrySession hands the device session of the refresh token oldRefresh over
// to the pair td that replaced it. A token without one (issued before
// devices were recorded) opens one, its login time unknown.
func (u *UsersRepository) carrySession(ctx context.Context, userID uint64, oldRefresh string, td *user.TokenDetails, info user.SessionInfo) error {
	id, err := u.Redis.Get(ctx, sessionOfPrefix+oldRefresh).Result()
	if err == redis.Nil {
		return u.writeSession(ctx, userID, uuid.NewString(), td, info, false)
	}
	if err != nil {
		return err
	}
	return u.writeSession(ctx, userID, id, td, info, false)
}

// writeSession points session id at the pair td and renews it. A blank
// client leaves the one recorded before: an app that does not say what it
// is (an older one) keeps the name it had.
func (u *UsersRepository) writeSession(ctx context.Context, userID uint64, id string, td *user.TokenDetails, info user.SessionInfo, created bool) error {
	now := time.Now()
	ttl := time.Unix(td.RtExpires, 0).Sub(now)
	fields := map[string]interface{}{
		"user":    strconv.FormatUint(userID, 10),
		"refresh": td.RefreshUuid,
		"seen":    now.Unix(),
		"ip":      info.IP,
	}
	if info.Client != "" {
		fields["client"] = info.Client
	}
	if created {
		fields["created"] = now.Unix()
	}

	key := deviceSessionPrefix + id
	devices := userDevicesPrefix + strconv.FormatUint(userID, 10)
	pipe := u.Redis.TxPipeline()
	pipe.HSet(ctx, key, fields)
	pipe.Expire(ctx, key, ttl)
	pipe.Set(ctx, sessionOfPrefix+td.RefreshUuid, id, ttl)
	pipe.SAdd(ctx, devices, id)
	pipe.Expire(ctx, devices, ttl)
	_, err := pipe.Exec(ctx)
	return err
}

// ListSessions returns the user's live device sessions, most recently active
// first. A session whose newest refresh token is gone (logged out, revoked,
// expired) is forgotten on the way.
func (u *UsersRepository) ListSessions(ctx context.Context, userID uint64) ([]user.Session, error) {
	uid := strconv.FormatUint(userID, 10)
	ids, err := u.Redis.SMembers(ctx, userDevicesPrefix+uid).Result()
	if err != nil {
		return nil, err
	}

	sessions := make([]user.Session, 0, len(ids))
	for _, id := range ids {
		fields, err := u.Redis.HGetAll(ctx, deviceSessionPrefix+id).Result()
		if err != nil {
			return nil, err
		}
		alive := false
		if len(fields) > 0 && fields["user"] == uid {
			n, err := u.Redis.Exists(ctx, refreshKeyPrefix+fields["refresh"],
				rotatedKeyPrefix+fields["refresh"]).Result()
			if err != nil {
				return nil, err
			}
			alive = n > 0
		}
		if !alive {
			if err := u.endSession(ctx, userID, id); err != nil {
				return nil, err
			}
			continue
		}

		session := user.Session{
			Id:         id,
			Client:     fields["client"],
			IP:         fields["ip"],
			LastSeenAt: unixField(fields["seen"]),
		}
		if fields["created"] != "" {
			created := unixField(fields["created"])
			session.CreatedAt = &created
		}
		sessions = append(sessions, session)
	}

	sort.Slice(sessions, func(i, j int) bool {
		return sessions[i].LastSeenAt.After(sessions[j].LastSeenAt)
	})
	return sessions, nil
}

func unixField(value string) time.Time {
	seconds, _ := strconv.ParseInt(value, 10, 64)
	return time.Unix(seconds, 0).UTC()
}

// SessionOfAccess returns the device session of an access token: the one of
// the refresh token it was handed out with.
func (u *UsersRepository) SessionOfAccess(ctx context.Context, accessUuid string) (string, error) {
	val, err := u.Redis.Get(ctx, accessKeyPrefix+accessUuid).Result()
	if err == redis.Nil {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	_, refreshUuid, err := parseSessionValue(val)
	if err != nil {
		return "", err
	}
	id, err := u.Redis.Get(ctx, sessionOfPrefix+refreshUuid).Result()
	if err == redis.Nil {
		return "", nil
	}
	return id, err
}

// RevokeSession signs device session id of the user out: its newest pair,
// and with it the token a rotation still pending replaced (revokeSession
// drops it).
func (u *UsersRepository) RevokeSession(ctx context.Context, userID uint64, id string) (bool, error) {
	fields, err := u.Redis.HGetAll(ctx, deviceSessionPrefix+id).Result()
	if err != nil {
		return false, err
	}
	if len(fields) == 0 || fields["user"] != strconv.FormatUint(userID, 10) {
		return false, nil
	}
	if _, err := u.revokeSession(ctx, fields["refresh"], refreshKeyPrefix, accessKeyPrefix); err != nil {
		return false, err
	}
	return true, u.endSession(ctx, userID, id)
}

// endSession forgets device session id; its tokens are revoked by the
// caller, or gone already.
func (u *UsersRepository) endSession(ctx context.Context, userID uint64, id string) error {
	pipe := u.Redis.TxPipeline()
	pipe.Del(ctx, deviceSessionPrefix+id)
	pipe.SRem(ctx, userDevicesPrefix+strconv.FormatUint(userID, 10), id)
	_, err := pipe.Exec(ctx)
	return err
}
