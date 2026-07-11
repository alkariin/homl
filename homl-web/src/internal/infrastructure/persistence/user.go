package persistence

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/masterdata"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/go-sql-driver/mysql"
	"github.com/jmoiron/sqlx"
	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"
)

// mysqlDuplicateEntry is MySQL error 1062: duplicate entry for a unique key.
const mysqlDuplicateEntry = 1062

// resetTokenKeyPrefix namespaces single-use password-reset tokens in Redis.
const resetTokenKeyPrefix = "reset:"

// Session keys are namespaced so they can never collide with other Redis
// usages (rate limiting, reset tokens). Each half of a session stores the
// uuid of its partner, so revoking one always revokes the pair, and a per-user
// set indexes every live session uuid for revoke-all (password change/reset).
const (
	accessKeyPrefix  = "auth:at:"
	refreshKeyPrefix = "auth:rt:"
	userSessionsKey  = "auth:user:"
)

// sessionValue encodes what a session key stores: the owning user id and the
// partner uuid of the other token of the pair.
func sessionValue(userID uint64, partnerUuid string) string {
	return strconv.FormatUint(userID, 10) + ":" + partnerUuid
}

// parseSessionValue reverses sessionValue.
func parseSessionValue(v string) (uint64, string, error) {
	id, partner, found := strings.Cut(v, ":")
	if !found {
		return 0, "", errors.New("malformed session value")
	}
	userID, err := strconv.ParseUint(id, 10, 64)
	if err != nil {
		return 0, "", err
	}
	return userID, partner, nil
}

type UsersRepository struct {
	DB     *sqlx.DB
	Redis  *redis.Client
	Crypto application.Encryptor
}

func NewUsersRepository(db *sqlx.DB, redis *redis.Client, crypto application.Encryptor) user.Repository {
	return &UsersRepository{
		DB:     db,
		Redis:  redis,
		Crypto: crypto,
	}
}

// Registration stores the user (password already hashed by the application
// layer) and seeds their default categories in one transaction.
func (u *UsersRepository) Registration(ctx context.Context, user *user.User, language *user.Language) error {
	tx, err := u.DB.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	res, err := tx.ExecContext(ctx, "INSERT INTO Users (username, password, language) VALUES (?, ?, ?)", user.Username, user.Password, *language)
	if err != nil {
		// An existing username violates the unique key: report it as a
		// conflict instead of leaking a raw driver error as a 500.
		var mysqlErr *mysql.MySQLError
		if errors.As(err, &mysqlErr) && mysqlErr.Number == mysqlDuplicateEntry {
			return apperror.NewConflict("username", user.Username)
		}
		return err
	}

	// Get the inserted user id.
	insertedID, err := res.LastInsertId()
	if err != nil {
		return err
	}
	user.ID = uint64(insertedID)

	// Create default categories, each carrying its explicit kind (date,
	// person, other) so the services never have to rely on id arithmetic.
	categories := masterdata.DefaultCategories()

	for i := 0; i < len(categories); i++ {
		encCategory, err := u.Crypto.Encrypt(categories[i].Name, user.ID)
		if err != nil {
			return err
		}

		_, err = tx.ExecContext(ctx, "INSERT INTO Categories (category, color, isLocked, kind, idUser) VALUES (?, ?, ?, ?, ?)", encCategory, categories[i].Color, 1, categories[i].Kind, user.ID)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (r *UsersRepository) FindById(ctx context.Context, idUser uint64) (*user.User, error) {
	user := user.User{}
	err := r.DB.GetContext(ctx, &user, "SELECT id, username, isFingerprintEnabled, isPinEnabled FROM Users WHERE id = ?;", idUser)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (u *UsersRepository) FindIdByUsername(ctx context.Context, username string) (uint64, error) {
	var idUser uint64
	err := u.DB.GetContext(ctx, &idUser, "SELECT id FROM Users WHERE username=?", username)
	if err != nil {
		return 0, err
	}
	return idUser, nil
}

func (u *UsersRepository) FindPasswordById(ctx context.Context, idUser uint64) (*string, error) {
	var password string
	err := u.DB.GetContext(ctx, &password, "SELECT password FROM Users WHERE id=?", idUser)
	if err != nil {
		return nil, err
	}
	return &password, nil
}

func (u *UsersRepository) FindByUsername(ctx context.Context, username string) (*user.User, error) {
	// Get the existing entry present in the database for the given username
	// We create another instance of `User` to store the credentials we get from the database
	storedUser := &user.User{}
	err := u.DB.GetContext(ctx, storedUser, "SELECT id, password, isPinEnabled FROM Users WHERE username=?", username)
	if err != nil {
		// sql.ErrNoRows when the username does not exist; the caller maps it to a 401
		return nil, err
	}
	return storedUser, nil
}

func (u *UsersRepository) FindPkeyAndChallengeById(ctx context.Context, idUser uint64) (*user.User, error) {
	storedUser := &user.User{}
	err := u.DB.GetContext(ctx, storedUser, "SELECT pkey, challenge FROM Users WHERE id=?", idUser)
	if err != nil {
		return nil, apperror.NewInternal()
	}
	return storedUser, nil
}

func (u *UsersRepository) UpdatePassword(ctx context.Context, idUser uint64, hashedPassword string) error {
	_, err := u.DB.ExecContext(ctx, "UPDATE Users SET password=? WHERE id=?", hashedPassword, idUser)
	return err
}

func (u *UsersRepository) UpdateChallenge(ctx context.Context, idUser uint64, challenge *string) error {
	_, err := u.DB.ExecContext(ctx, "UPDATE Users SET challenge=? WHERE id=?", challenge, idUser)
	return err
}

func (r *UsersRepository) ResetPinCounter(ctx context.Context, idUser uint64) error {
	// MySQL reports 0 affected rows when the counter is already 0, so the
	// affected-rows count cannot distinguish "no such user" from "no-op reset".
	_, err := r.DB.ExecContext(ctx, "UPDATE Users SET pinTryCounter = 0 WHERE id = ?", idUser)
	if err != nil {
		return err
	}

	return nil
}

func (r *UsersRepository) CheckPin(ctx context.Context, idUser uint64, pin string) error {
	// Fetch the stored (hashed) pin and the current failure counter.
	var storedPin *string
	var pinTryCounter *uint
	row := r.DB.QueryRowContext(ctx, `SELECT pin, pinTryCounter FROM Users WHERE id = ?`, idUser)
	if err := row.Scan(&storedPin, &pinTryCounter); err != nil {
		return err
	}

	// Hard lockout: once locked, even a correct pin is refused until the user
	// re-authenticates with their password (which resets the counter on Login).
	if pinTryCounter != nil && *pinTryCounter >= user.MaxPinTries {
		return apperror.NewAuthorization("Pin is locked") // this string is used in FE
	}

	if storedPin == nil {
		return apperror.NewAuthorization("Pin code not correct")
	}

	// Constant-time comparison against the bcrypt hash.
	if err := bcrypt.CompareHashAndPassword([]byte(*storedPin), []byte(pin)); err != nil {
		// Wrong pin: increment the failure counter.
		res, err2 := r.DB.ExecContext(ctx, "UPDATE Users SET pinTryCounter = IFNULL(pinTryCounter, 0) + 1 WHERE id = ?", idUser)
		if err2 != nil {
			return err2
		}
		if rowsAffected, err2 := res.RowsAffected(); rowsAffected == 0 || err2 != nil {
			return apperror.NewInternal()
		}

		// Re-read the counter to tell the FE whether the pin just got locked.
		var counter *uint
		if err2 := r.DB.QueryRowContext(ctx, `SELECT pinTryCounter FROM Users WHERE id = ?`, idUser).Scan(&counter); err2 != nil {
			return err2
		}
		if counter != nil && *counter >= user.MaxPinTries {
			return apperror.NewAuthorization("Pin is locked") // this string is used in FE
		}
		return apperror.NewAuthorization("Pin code not correct")
	}

	// Correct pin: reset the counter. Tolerate a no-op update (counter already 0)
	// since this driver's RowsAffected reports changed rows, not matched rows.
	if _, err := r.DB.ExecContext(ctx, "UPDATE Users SET pinTryCounter = 0 WHERE id = ?", idUser); err != nil {
		return err
	}
	return nil
}

func (r *UsersRepository) UpdatePinAndFingerprint(ctx context.Context, user *user.User, removePkey bool, removePin bool) error {
	query := "UPDATE Users SET isFingerprintEnabled = ?, isPinEnabled = ?"
	args := []interface{}{user.IsFingerprintEnabled, user.IsPinEnabled}

	if removePkey {
		query += ", pkey = ?"
		args = append(args, nil)
	} else if user.Pkey != nil {
		query += ", pkey = ?"
		args = append(args, user.Pkey)
	}

	if removePin {
		query += ", pin = ?"
		args = append(args, nil)
	} else if user.Pin != nil {
		query += ", pin = ?"
		args = append(args, user.Pin)
	}

	if !user.IsFingerprintEnabled && !user.IsPinEnabled {
		query += ", challenge = ?"
		args = append(args, nil)
	}

	query += " WHERE id = ?"
	args = append(args, user.ID)

	res, err := r.DB.ExecContext(ctx, query, args...)
	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	return nil
}

func (u *UsersRepository) CreateAuth(ctx context.Context, userid uint64, td *user.TokenDetails) error {
	at := time.Unix(td.AtExpires, 0) //converting Unix to UTC(to Time object)
	rt := time.Unix(td.RtExpires, 0)
	now := time.Now()

	pipe := u.Redis.TxPipeline()
	pipe.Set(ctx, accessKeyPrefix+td.AccessUuid, sessionValue(userid, td.RefreshUuid), at.Sub(now))
	pipe.Set(ctx, refreshKeyPrefix+td.RefreshUuid, sessionValue(userid, td.AccessUuid), rt.Sub(now))
	// Index the pair for revoke-all. The set lives as long as the longest
	// refresh token; stale members are dropped on every revocation.
	userKey := userSessionsKey + strconv.FormatUint(userid, 10)
	pipe.SAdd(ctx, userKey, td.AccessUuid, td.RefreshUuid)
	pipe.Expire(ctx, userKey, rt.Sub(now))
	_, err := pipe.Exec(ctx)
	return err
}

// revokeSession deletes both halves of a session given one of its uuids.
func (u *UsersRepository) revokeSession(ctx context.Context, uuid string, keyPrefix string, partnerPrefix string) (int64, error) {
	val, err := u.Redis.Get(ctx, keyPrefix+uuid).Result()
	if err == redis.Nil {
		return 0, nil
	}
	if err != nil {
		return 0, err
	}

	userID, partnerUuid, err := parseSessionValue(val)
	if err != nil {
		return 0, err
	}

	pipe := u.Redis.TxPipeline()
	deleted := pipe.Del(ctx, keyPrefix+uuid, partnerPrefix+partnerUuid)
	pipe.SRem(ctx, userSessionsKey+strconv.FormatUint(userID, 10), uuid, partnerUuid)
	if _, err := pipe.Exec(ctx); err != nil {
		return 0, err
	}
	return deleted.Val(), nil
}

// RevokeSessionByAccess deletes the session pair identified by an access
// token uuid (logout).
func (u *UsersRepository) RevokeSessionByAccess(ctx context.Context, accessUuid string) (int64, error) {
	return u.revokeSession(ctx, accessUuid, accessKeyPrefix, refreshKeyPrefix)
}

// RevokeSessionByRefresh deletes the session pair identified by a refresh
// token uuid (token rotation). Revoking the paired access token too means a
// rotated-out access token dies immediately instead of surviving to expiry.
func (u *UsersRepository) RevokeSessionByRefresh(ctx context.Context, refreshUuid string) (int64, error) {
	return u.revokeSession(ctx, refreshUuid, refreshKeyPrefix, accessKeyPrefix)
}

// RevokeAllSessions deletes every live session of the user (password change
// or reset): a stolen refresh token must not survive a credential rotation.
func (u *UsersRepository) RevokeAllSessions(ctx context.Context, idUser uint64) error {
	userKey := userSessionsKey + strconv.FormatUint(idUser, 10)

	uuids, err := u.Redis.SMembers(ctx, userKey).Result()
	if err != nil {
		return err
	}

	keys := make([]string, 0, 2*len(uuids)+1)
	for _, id := range uuids {
		// Membership does not record the token type: delete both candidates.
		keys = append(keys, accessKeyPrefix+id, refreshKeyPrefix+id)
	}
	keys = append(keys, userKey)

	return u.Redis.Del(ctx, keys...).Err()
}

// RefreshSessionExists reports whether a refresh token uuid still has a live
// session (i.e. has not been revoked or rotated out).
func (u *UsersRepository) RefreshSessionExists(ctx context.Context, refreshUuid string) (bool, error) {
	n, err := u.Redis.Exists(ctx, refreshKeyPrefix+refreshUuid).Result()
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

func (u *UsersRepository) FetchAuth(ctx context.Context, authD *user.AccessDetails) (uint64, error) {
	val, err := u.Redis.Get(ctx, accessKeyPrefix+authD.AccessUuid).Result()
	if err != nil {
		return 0, err
	}
	userID, _, err := parseSessionValue(val)
	if err != nil {
		return 0, err
	}
	return userID, nil
}

func (u *UsersRepository) StoreResetToken(ctx context.Context, userId uint64, token string, ttl time.Duration) error {
	return u.Redis.Set(ctx, resetTokenKeyPrefix+token, strconv.FormatUint(userId, 10), ttl).Err()
}

func (u *UsersRepository) ConsumeResetToken(ctx context.Context, token string) (uint64, error) {
	key := resetTokenKeyPrefix + token

	// GET then DEL in a single transaction so a token can be redeemed at most
	// once, even under concurrent requests.
	getCmd := u.Redis.TxPipeline()
	val := getCmd.Get(ctx, key)
	getCmd.Del(ctx, key)
	if _, err := getCmd.Exec(ctx); err != nil {
		return 0, apperror.NewAuthorization("Not authorized")
	}

	userID, err := strconv.ParseUint(val.Val(), 10, 64)
	if err != nil {
		return 0, apperror.NewAuthorization("Not authorized")
	}
	return userID, nil
}
