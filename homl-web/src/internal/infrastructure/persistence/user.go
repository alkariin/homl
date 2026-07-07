package persistence

import (
	"context"
	"database/sql"
	"strconv"
	"time"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/masterdata"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/go-redis/redis/v7"
	"golang.org/x/crypto/bcrypt"
)

// passwordBcryptCost aliases the domain constant so it stays reachable inside
// methods whose "user" parameter shadows the package name.
const passwordBcryptCost = user.PasswordBcryptCost

// resetTokenKeyPrefix namespaces single-use password-reset tokens in Redis.
const resetTokenKeyPrefix = "reset:"

type UsersRepository struct {
	DB     *sql.DB
	Redis  *redis.Client
	Crypto application.Encryptor
}

func NewUsersRepository(db *sql.DB, redis *redis.Client, crypto application.Encryptor) user.Repository {
	return &UsersRepository{
		DB:     db,
		Redis:  redis,
		Crypto: crypto,
	}
}

func (u *UsersRepository) Registration(user *user.User, language *user.Language) error {
	ctx := context.Background()
	tx, err := u.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	// Salt and hash the password using the bcrypt algorithm.
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(user.Password), passwordBcryptCost)
	if err != nil {
		return err
	}

	// Next, insert the username, along with the hashed password into the database.
	res, err := tx.Exec("INSERT INTO Users (username, password, language) VALUES (?, ?, ?)", user.Username, string(hashedPassword), *language)
	if err != nil {
		tx.Rollback()
		return err
	}

	// Get the inserted user id.
	insertedID, err := res.LastInsertId()
	if err != nil {
		tx.Rollback()
		return err
	}
	user.ID = uint64(insertedID)

	// Create default categories
	categories := masterdata.DefaultCategories()

	var idCategoryDate uint = 0
	for i := 0; i < len(categories); i++ {
		encCategory, err := u.Crypto.Encrypt(categories[i].Name)
		if err != nil {
			tx.Rollback()
			return err
		}

		_, err = tx.Exec("INSERT INTO Categories (category, color, isLocked, idUser) VALUES (?, ?, ?, ?)", encCategory, categories[i].Color, 1, user.ID)
		if err != nil {
			tx.Rollback()
			return err
		}

		if i == 0 { // Get id of the category "dates"
			row := tx.QueryRow("SELECT LAST_INSERT_ID();")
			err = row.Scan(&idCategoryDate)
			if err != nil {
				tx.Rollback()
				return err
			}
		}
	}

	if idCategoryDate == 0 {
		tx.Rollback()
		return apperror.NewInternal()
	}

	return tx.Commit()
}

func (r *UsersRepository) FindById(idUser uint64) (*user.User, error) {
	user := user.User{}
	row := r.DB.QueryRow("SELECT id, username, isFingerprintEnabled, isPinEnabled FROM Users WHERE id = ?;", idUser)
	err := row.Scan(&user.ID, &user.Username, &user.IsFingerprintEnabled, &user.IsPinEnabled)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (u *UsersRepository) FindIdByUsername(username string) (uint64, error) {
	storedUser := &user.User{}
	result := u.DB.QueryRow("SELECT id FROM Users WHERE username=?", username)
	err := result.Scan(&storedUser.ID)
	if err != nil {
		return 0, err
	}
	return storedUser.ID, nil
}

func (u *UsersRepository) FindPasswordById(idUser uint64) (*string, error) {
	var password string
	result := u.DB.QueryRow("SELECT password FROM Users WHERE id=?", idUser)
	err := result.Scan(&password)
	if err != nil {
		return nil, err
	}
	return &password, nil
}

func (u *UsersRepository) FindByUsername(username string) (*user.User, error) {
	// Get the existing entry present in the database for the given username
	// We create another instance of `User` to store the credentials we get from the database
	storedUser := &user.User{}
	result := u.DB.QueryRow("SELECT id, password, isPinEnabled FROM Users WHERE username=?", username)
	// Store the obtained password in `storedUser`
	err := result.Scan(&storedUser.ID, &storedUser.Password, &storedUser.IsPinEnabled)
	if err != nil {
		// If an entry with the username does not exist, send an "Unauthorized"(401) status
		if err == sql.ErrNoRows {
			return nil, err
		}
		// If the error is of any other type, send a 500 status
		return nil, err
	}
	return storedUser, nil
}

func (u *UsersRepository) FindPkeyAndChallengeById(idUser uint64) (*user.User, error) {
	storedUser := &user.User{}
	result := u.DB.QueryRow("SELECT pkey, challenge FROM Users WHERE id=?", idUser)
	err := result.Scan(&storedUser.Pkey, &storedUser.Challenge)
	if err != nil {
		return nil, apperror.NewInternal()
	}
	return storedUser, nil
}

func (u *UsersRepository) UpdatePassword(idUser uint64, hashedPassword string) error {
	if _, err := u.DB.Exec("UPDATE Users SET password=? WHERE id=?", hashedPassword, idUser); err != nil {
		return err
	}
	return nil
}

func (u *UsersRepository) UpdateChallenge(idUser uint64, challenge *string) error {
	if _, err := u.DB.Exec("UPDATE Users SET challenge=? WHERE id=?", challenge, idUser); err != nil {
		return err
	}
	return nil
}

func (r *UsersRepository) ResetPinCounter(idUser uint64) error {
	// MySQL reports 0 affected rows when the counter is already 0, so the
	// affected-rows count cannot distinguish "no such user" from "no-op reset".
	_, err := r.DB.Exec("UPDATE Users SET pinTryCounter = 0 WHERE id = ?", idUser)
	if err != nil {
		return err
	}

	return nil
}

func (r *UsersRepository) CheckPin(idUser uint64, pin string) error {
	// Fetch the stored (hashed) pin and the current failure counter.
	var storedPin *string
	var pinTryCounter *uint
	row := r.DB.QueryRow(`SELECT pin, pinTryCounter FROM Users WHERE id = ?`, idUser)
	if err := row.Scan(&storedPin, &pinTryCounter); err != nil {
		return err
	}

	// Hard lockout: once locked, even a correct pin is refused until the user
	// re-authenticates with their password (which resets the counter on Login).
	if pinTryCounter != nil && *pinTryCounter >= 3 {
		return apperror.NewAuthorization("Pin is locked") // this string is used in FE
	}

	if storedPin == nil {
		return apperror.NewAuthorization("Pin code not correct")
	}

	// Constant-time comparison against the bcrypt hash.
	if err := bcrypt.CompareHashAndPassword([]byte(*storedPin), []byte(pin)); err != nil {
		// Wrong pin: increment the failure counter.
		res, err2 := r.DB.Exec("UPDATE Users SET pinTryCounter = IFNULL(pinTryCounter, 0) + 1 WHERE id = ?", idUser)
		if err2 != nil {
			return err2
		}
		if rowsAffected, err2 := res.RowsAffected(); rowsAffected == 0 || err2 != nil {
			return apperror.NewInternal()
		}

		// Re-read the counter to tell the FE whether the pin just got locked.
		var counter *uint
		if err2 := r.DB.QueryRow(`SELECT pinTryCounter FROM Users WHERE id = ?`, idUser).Scan(&counter); err2 != nil {
			return err2
		}
		if counter != nil && *counter >= 3 {
			return apperror.NewAuthorization("Pin is locked") // this string is used in FE
		}
		return apperror.NewAuthorization("Pin code not correct")
	}

	// Correct pin: reset the counter. Tolerate a no-op update (counter already 0)
	// since this driver's RowsAffected reports changed rows, not matched rows.
	if _, err := r.DB.Exec("UPDATE Users SET pinTryCounter = 0 WHERE id = ?", idUser); err != nil {
		return err
	}
	return nil
}

func (r *UsersRepository) UpdatePinAndFingerprint(user *user.User, removePkey bool, removePin bool) error {
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

	res, err := r.DB.Exec(query, args...)
	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	return nil
}

func (u *UsersRepository) DeleteAuth(givenUuid string) (int64, error) {
	deleted, err := u.Redis.Del(givenUuid).Result()
	if err != nil {
		return 0, err
	}

	return deleted, nil
}

func (u *UsersRepository) CreateAuth(userid uint64, td *user.TokenDetails) error {
	at := time.Unix(td.AtExpires, 0) //converting Unix to UTC(to Time object)
	rt := time.Unix(td.RtExpires, 0)
	now := time.Now()

	errAccess := u.Redis.Set(td.AccessUuid, strconv.Itoa(int(userid)), at.Sub(now)).Err()
	if errAccess != nil {
		return errAccess
	}
	errRefresh := u.Redis.Set(td.RefreshUuid, strconv.Itoa(int(userid)), rt.Sub(now)).Err()
	if errRefresh != nil {
		return errRefresh
	}
	return nil
}

func (u *UsersRepository) FetchAuth(authD *user.AccessDetails) (uint64, error) {
	userid, err := u.Redis.Get(authD.AccessUuid).Result()
	if err != nil {
		return 0, err
	}
	userID, _ := strconv.ParseUint(userid, 10, 64)
	return userID, nil
}

func (u *UsersRepository) StoreResetToken(userId uint64, token string, ttl time.Duration) error {
	return u.Redis.Set(resetTokenKeyPrefix+token, strconv.FormatUint(userId, 10), ttl).Err()
}

func (u *UsersRepository) ConsumeResetToken(token string) (uint64, error) {
	key := resetTokenKeyPrefix + token

	// GET then DEL in a single transaction so a token can be redeemed at most
	// once, even under concurrent requests.
	getCmd := u.Redis.TxPipeline()
	val := getCmd.Get(key)
	getCmd.Del(key)
	if _, err := getCmd.Exec(); err != nil {
		return 0, apperror.NewAuthorization("Not authorized")
	}

	userID, err := strconv.ParseUint(val.Val(), 10, 64)
	if err != nil {
		return 0, apperror.NewAuthorization("Not authorized")
	}
	return userID, nil
}
