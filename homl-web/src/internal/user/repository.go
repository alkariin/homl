package user

import (
	"context"
	"database/sql"
	"encoding/json"
	"strconv"
	"time"

	"github.com/alkariin/homl/homl-web/internal/domain"
	"github.com/alkariin/homl/homl-web/internal/shared"
	"github.com/go-redis/redis/v7"
	"golang.org/x/crypto/bcrypt"
)

type UsersRepository struct {
	DB    *sql.DB
	Redis *redis.Client
}

func NewUsersRepository(db *sql.DB, redis *redis.Client) domain.UsersRepository {
	return &UsersRepository{
		DB:    db,
		Redis: redis,
	}
}

func (u *UsersRepository) Registration(user *domain.User, language *domain.Language) (map[string]string, error) {
	ctx := context.Background()
	tx, err := u.DB.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}

	// Salt and hash the password using the bcrypt algorithm
	// The second argument is the cost of hashing, which we arbitrarily set as 8 (this value can be more or less, depending on the computing power you wish to utilize)
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(user.Password), 8)
	if err != nil {
		return nil, err
	}

	// Next, insert the username, along with the hashed password into the database
	_, err = tx.Query("INSERT INTO Users (username, password, language) VALUES (?, ?, ?)", user.Username, string(hashedPassword), *language)
	if err != nil {
		tx.Rollback()
		return nil, err
	}

	// Get user id
	result := tx.QueryRow("SELECT id FROM Users WHERE username=? AND password=?", user.Username, string(hashedPassword))
	if result == nil {
		tx.Rollback()
		return nil, err
	}

	err = result.Scan(&user.ID)
	if err != nil {
		tx.Rollback()
		return nil, err
	}

	// Create access and refresh tokens
	ts, err := shared.CreateToken(user.ID)
	if err != nil {
		tx.Rollback()
		return nil, err
	}
	err = u.CreateAuth(user.ID, ts)
	if err != nil {
		tx.Rollback()
		return nil, err
	}
	tokens := map[string]string{
		"access_token":  ts.AccessToken,
		"refresh_token": ts.RefreshToken,
	}

	// Create default categories
	var constants map[string]domain.CategoryConstant
	constBytes, err := shared.GetConstants()
	if err != nil {
		tx.Rollback()
		return nil, err
	}
	json.Unmarshal(constBytes, &constants)
	categories := constants["CATEGORIES"]

	var idCategoryDate uint = 0
	for i := 0; i < len(categories); i++ {
		encCategory, err := shared.Encrypt(categories[i].Name)
		if err != nil {
			tx.Rollback()
			return nil, err
		}

		_, err = tx.Query("INSERT INTO Categories (category, color, isLocked, idUser) VALUES (?, ?, ?, ?)", encCategory, categories[i].Color, 1, user.ID)
		if err != nil {
			tx.Rollback()
			return nil, err
		}

		if i == 0 { // Get id of the category "dates"
			row := tx.QueryRow("SELECT LAST_INSERT_ID();")
			err = row.Scan(&idCategoryDate)
			if err != nil {
				tx.Rollback()
				return nil, err
			}
		}
	}

	if idCategoryDate == 0 {
		tx.Rollback()
		return nil, shared.NewInternal()
	}

	err = tx.Commit()
	if err != nil {
		return nil, err
	}

	return tokens, nil
}

func (r *UsersRepository) FindById(idUser uint64) (*domain.User, error) {
	user := domain.User{}
	row := r.DB.QueryRow("SELECT id, username, isFingerprintEnabled, isPinEnabled FROM Users WHERE id = ?;", idUser)
	err := row.Scan(&user.ID, &user.Username, &user.IsFingerprintEnabled, &user.IsPinEnabled)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (u *UsersRepository) FindIdByUsername(username string) (uint64, error) {
	storedUser := &domain.User{}
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

func (u *UsersRepository) FindByUsername(username string) (*domain.User, error) {
	// Get the existing entry present in the database for the given username
	// We create another instance of `User` to store the credentials we get from the database
	storedUser := &domain.User{}
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

func (u *UsersRepository) FindPkeyAndChallengeById(idUser uint64) (*domain.User, error) {
	storedUser := &domain.User{}
	result := u.DB.QueryRow("SELECT pkey, challenge FROM Users WHERE id=?", idUser)
	err := result.Scan(&storedUser.Pkey, &storedUser.Challenge)
	if err != nil {
		return nil, shared.NewInternal()
	}
	return storedUser, nil
}

func (u *UsersRepository) UpdatePassword(idUser uint64, hashedPassword string) error {
	result := u.DB.QueryRow("UPDATE Users SET password=? WHERE id=?", hashedPassword, idUser)
	if result == nil {
		return shared.NewInternal()
	}
	return nil
}

func (u *UsersRepository) UpdateChallenge(idUser uint64, challenge *string) error {
	result := u.DB.QueryRow("UPDATE Users SET challenge=? WHERE id=?", challenge, idUser)
	if result == nil {
		return shared.NewInternal()
	}
	return nil
}

func (r *UsersRepository) ResetPinCounter(idUser uint64) error {
	res, err := r.DB.Exec("UPDATE Users SET pinTryCounter = 0 WHERE id = ?", idUser)

	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return shared.NewInternal()
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
		return shared.NewAuthorization("Pin is locked") // this string is used in FE
	}

	if storedPin == nil {
		return shared.NewAuthorization("Pin code not correct")
	}

	// Constant-time comparison against the bcrypt hash.
	if err := bcrypt.CompareHashAndPassword([]byte(*storedPin), []byte(pin)); err != nil {
		// Wrong pin: increment the failure counter.
		res, err2 := r.DB.Exec("UPDATE Users SET pinTryCounter = IFNULL(pinTryCounter, 0) + 1 WHERE id = ?", idUser)
		if err2 != nil {
			return err2
		}
		if rowsAffected, err2 := res.RowsAffected(); rowsAffected == 0 || err2 != nil {
			return shared.NewInternal()
		}

		// Re-read the counter to tell the FE whether the pin just got locked.
		var counter *uint
		if err2 := r.DB.QueryRow(`SELECT pinTryCounter FROM Users WHERE id = ?`, idUser).Scan(&counter); err2 != nil {
			return err2
		}
		if counter != nil && *counter >= 3 {
			return shared.NewAuthorization("Pin is locked") // this string is used in FE
		}
		return shared.NewAuthorization("Pin code not correct")
	}

	// Correct pin: reset the counter. Tolerate a no-op update (counter already 0)
	// since this driver's RowsAffected reports changed rows, not matched rows.
	if _, err := r.DB.Exec("UPDATE Users SET pinTryCounter = 0 WHERE id = ?", idUser); err != nil {
		return err
	}
	return nil
}

func (r *UsersRepository) UpdatePinAndFingerprint(user *domain.User, removePkey bool, removePin bool) error {
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
		return shared.NewInternal()
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

func (u *UsersRepository) CreateAuth(userid uint64, td *domain.TokenDetails) error {
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

func (u *UsersRepository) FetchAuth(authD *domain.AccessDetails) (uint64, error) {
	userid, err := u.Redis.Get(authD.AccessUuid).Result()
	if err != nil {
		return 0, err
	}
	userID, _ := strconv.ParseUint(userid, 10, 64)
	return userID, nil
}
