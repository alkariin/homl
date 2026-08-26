package application_test

import (
	"context"
	"errors"
	"net/http"
	"testing"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/alkariin/homl/homl-web/test/mocks"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"golang.org/x/crypto/bcrypt"
)

func TestSecureAuth(t *testing.T) {

	pkey := "asfdslfjls"
	pin := "0000"

	mockUsersRepo := new(mocks.MockUsersRepo)
	usersService := application.NewUsersService(&application.UserConfig{
		UsersRepository: mockUsersRepo,
	})

	t.Run("Update u with good inputs", func(t *testing.T) {
		u := &user.User{
			ID:                   1,
			IsFingerprintEnabled: true,
			Pkey:                 nil,
			Pin:                  nil,
			IsPinEnabled:         false,
		}

		userResponse := &user.UserResponse{
			IsFingerprintEnabled: true,
			IsPinEnabled:         false,
		}

		removePkey := !u.IsFingerprintEnabled && !u.IsPinEnabled
		removePin := !u.IsPinEnabled

		mockUsersRepo.On("UpdatePinAndFingerprint", u, removePkey, removePin).Return(nil)
		mockUsersRepo.On("FindById", u.ID).Return(u, nil)

		resultUser, err := usersService.SecureAuth(context.Background(), u)

		assert.NoError(t, err)
		assert.Equal(t, resultUser, userResponse)
		mockUsersRepo.AssertExpectations(t)
	})

	t.Run("Check that fingerprint and pin can't be both activated", func(t *testing.T) {
		u := &user.User{
			ID:                   1,
			IsFingerprintEnabled: true,
			IsPinEnabled:         true,
		}

		resultUser, err := usersService.SecureAuth(context.Background(), u)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})

	t.Run("Check that pin should not be provided if fingerprint is enabled", func(t *testing.T) {
		u := &user.User{
			ID:                   1,
			IsFingerprintEnabled: true,
			Pin:                  &pin,
		}

		resultUser, err := usersService.SecureAuth(context.Background(), u)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})

	t.Run("Check that pin should not be provided if pin feature is disabled", func(t *testing.T) {
		u := &user.User{
			ID:           1,
			IsPinEnabled: false,
			Pin:          &pin,
		}

		resultUser, err := usersService.SecureAuth(context.Background(), u)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})

	t.Run("Check that pKey must be here if pin is given", func(t *testing.T) {
		u := &user.User{
			ID:           1,
			IsPinEnabled: true,
			Pin:          &pin,
		}

		resultUser, err := usersService.SecureAuth(context.Background(), u)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})

	t.Run("Check that pKey must be nil if both fingerprint and pin are disabled", func(t *testing.T) {
		u := &user.User{
			ID:                   1,
			IsFingerprintEnabled: false,
			IsPinEnabled:         false,
			Pkey:                 &pkey,
		}

		resultUser, err := usersService.SecureAuth(context.Background(), u)

		assert.Nil(t, resultUser)
		assert.Error(t, err)
	})
}

func TestLogin(t *testing.T) {
	const password = "Demo1234!"
	hashed, _ := bcrypt.GenerateFromPassword([]byte(password), 8)

	t.Run("Returns an access/refresh token pair on valid credentials", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		stored := &user.User{ID: 1, Username: "demo@homl.local", Password: string(hashed)}
		mockRepo.On("FindByUsername", "demo@homl.local").Return(stored, nil)
		mockRepo.On("CreateAuth", uint64(1), mock.AnythingOfType("*user.TokenDetails")).Return(nil)

		tokens, err := svc.Login(context.Background(), &user.User{Username: "demo@homl.local", Password: password})

		assert.NoError(t, err)
		assert.NotEmpty(t, tokens["access_token"])
		assert.NotEmpty(t, tokens["refresh_token"])
		mockRepo.AssertExpectations(t)
	})

	t.Run("Rejects a wrong password without issuing tokens", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		stored := &user.User{ID: 1, Username: "demo@homl.local", Password: string(hashed)}
		mockRepo.On("FindByUsername", "demo@homl.local").Return(stored, nil)

		tokens, err := svc.Login(context.Background(), &user.User{Username: "demo@homl.local", Password: "wrong-password"})

		assert.Error(t, err)
		assert.Nil(t, tokens)
		mockRepo.AssertNotCalled(t, "CreateAuth")
	})

	t.Run("Rejects an unknown user", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		mockRepo.On("FindByUsername", "ghost@homl.local").Return(nil, assert.AnError)

		tokens, err := svc.Login(context.Background(), &user.User{Username: "ghost@homl.local", Password: password})

		assert.Error(t, err)
		assert.Nil(t, tokens)
	})
}

func TestLogout(t *testing.T) {
	t.Run("Clears the challenge and deletes the auth entry", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		ad := &user.AccessDetails{AccessUuid: "uuid-1", UserId: 1}
		mockRepo.On("UpdateChallenge", uint64(1), (*string)(nil)).Return(nil)
		mockRepo.On("RevokeSessionByAccess", "uuid-1").Return(int64(1), nil)

		err := svc.Logout(context.Background(), ad)

		assert.NoError(t, err)
		mockRepo.AssertExpectations(t)
	})

	t.Run("Errors when no auth entry was deleted", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		ad := &user.AccessDetails{AccessUuid: "uuid-missing", UserId: 1}
		mockRepo.On("UpdateChallenge", uint64(1), (*string)(nil)).Return(nil)
		mockRepo.On("RevokeSessionByAccess", "uuid-missing").Return(int64(0), nil)

		err := svc.Logout(context.Background(), ad)

		assert.Error(t, err)
		mockRepo.AssertExpectations(t)
	})
}

// isSixDigits matches the emailed reset code format.
func isSixDigits(s string) bool {
	if len(s) != 6 {
		return false
	}
	for _, c := range s {
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}

func TestResetPassword(t *testing.T) {
	t.Run("Stores and mails a 6-digit code in the user's language", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		mockMailer := new(mocks.MockMailer)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens, Mailer: mockMailer})

		mockRepo.On("FindIdByUsername", "demo@homl.local").Return(uint64(1), nil)
		mockRepo.On("StoreResetCode", uint64(1), mock.MatchedBy(isSixDigits), mock.AnythingOfType("time.Duration")).Return(nil)
		mockRepo.On("FindSettingsByIdUser", uint64(1)).Return(&user.Settings{Language: "fr"}, nil)
		mockMailer.On("SendPasswordResetCode", "demo@homl.local", mock.MatchedBy(isSixDigits), user.Language("fr")).Return(nil)

		err := svc.ResetPassword(context.Background(), &user.User{Username: "demo@homl.local"})

		assert.NoError(t, err)
		mockRepo.AssertExpectations(t)
		mockMailer.AssertExpectations(t)
	})

	t.Run("Falls back to English when the settings cannot be loaded", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		mockMailer := new(mocks.MockMailer)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens, Mailer: mockMailer})

		mockRepo.On("FindIdByUsername", "demo@homl.local").Return(uint64(1), nil)
		mockRepo.On("StoreResetCode", uint64(1), mock.AnythingOfType("string"), mock.AnythingOfType("time.Duration")).Return(nil)
		mockRepo.On("FindSettingsByIdUser", uint64(1)).Return(nil, assert.AnError)
		mockMailer.On("SendPasswordResetCode", "demo@homl.local", mock.AnythingOfType("string"), user.Language("en")).Return(nil)

		err := svc.ResetPassword(context.Background(), &user.User{Username: "demo@homl.local"})

		assert.NoError(t, err)
		mockMailer.AssertExpectations(t)
	})

	t.Run("Stays silent on an unknown email (no enumeration)", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		mockMailer := new(mocks.MockMailer)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens, Mailer: mockMailer})

		mockRepo.On("FindIdByUsername", "ghost@homl.local").Return(uint64(0), assert.AnError)

		err := svc.ResetPassword(context.Background(), &user.User{Username: "ghost@homl.local"})

		assert.NoError(t, err)
		mockRepo.AssertNotCalled(t, "StoreResetCode")
		mockMailer.AssertNotCalled(t, "SendPasswordResetCode")
	})

	t.Run("Stays silent and skips the email during the send cooldown", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		mockMailer := new(mocks.MockMailer)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens, Mailer: mockMailer})

		mockRepo.On("FindIdByUsername", "demo@homl.local").Return(uint64(1), nil)
		mockRepo.On("StoreResetCode", uint64(1), mock.AnythingOfType("string"), mock.AnythingOfType("time.Duration")).Return(user.ErrResetCooldown)

		err := svc.ResetPassword(context.Background(), &user.User{Username: "demo@homl.local"})

		assert.NoError(t, err)
		mockMailer.AssertNotCalled(t, "SendPasswordResetCode")
	})

	t.Run("Rejects a malformed email", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		err := svc.ResetPassword(context.Background(), &user.User{Username: "not-an-email"})

		assert.Error(t, err)
		mockRepo.AssertNotCalled(t, "FindIdByUsername")
	})
}

func TestConfirmResetPassword(t *testing.T) {
	t.Run("Consumes the code and sets the new password", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		mockRepo.On("FindIdByUsername", "demo@homl.local").Return(uint64(1), nil)
		mockRepo.On("ConsumeResetCode", uint64(1), "123456").Return(nil)
		mockRepo.On("UpdatePassword", uint64(1), mock.AnythingOfType("string")).Return(nil)
		mockRepo.On("RevokeAllSessions", uint64(1)).Return(nil)
		mockRepo.On("CreateAuth", uint64(1), mock.AnythingOfType("*user.TokenDetails")).Return(nil)

		tokens, err := svc.ConfirmResetPassword(context.Background(), "demo@homl.local", "123456", "NewPass123!")

		assert.NoError(t, err)
		assert.NotEmpty(t, tokens["access_token"])
		mockRepo.AssertExpectations(t)
	})

	t.Run("Rejects a wrong or expired code", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		mockRepo.On("FindIdByUsername", "demo@homl.local").Return(uint64(1), nil)
		mockRepo.On("ConsumeResetCode", uint64(1), "000000").Return(assert.AnError)

		tokens, err := svc.ConfirmResetPassword(context.Background(), "demo@homl.local", "000000", "NewPass123!")

		assert.Error(t, err)
		assert.Nil(t, tokens)
		mockRepo.AssertNotCalled(t, "UpdatePassword")
	})

	t.Run("Rejects an unknown email with the same error", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		mockRepo.On("FindIdByUsername", "ghost@homl.local").Return(uint64(0), assert.AnError)

		tokens, err := svc.ConfirmResetPassword(context.Background(), "ghost@homl.local", "123456", "NewPass123!")

		assert.Error(t, err)
		assert.Nil(t, tokens)
		mockRepo.AssertNotCalled(t, "ConsumeResetCode")
	})
}

func TestRefresh(t *testing.T) {
	// mintRefreshToken returns a valid refresh token for user 1 along with its uuid.
	mintRefreshToken := func(t *testing.T) (string, string) {
		t.Helper()
		td, err := testTokens.CreateToken(1)
		assert.NoError(t, err)
		return td.RefreshToken, td.RefreshUuid
	}

	t.Run("Rotates the session pair and mints new tokens", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		refreshToken, refreshUuid := mintRefreshToken(t)

		mockRepo.On("FindById", uint64(1)).Return(&user.User{ID: 1}, nil)
		mockRepo.On("RevokeSessionByRefresh", refreshUuid).Return(int64(2), nil)
		mockRepo.On("CreateAuth", uint64(1), mock.AnythingOfType("*user.TokenDetails")).Return(nil)

		tokens, err := svc.Refresh(context.Background(), &user.RefreshInput{Refresh_token: refreshToken})

		assert.NoError(t, err)
		assert.NotEmpty(t, tokens["access_token"])
		assert.NotEmpty(t, tokens["refresh_token"])
		mockRepo.AssertExpectations(t)
	})

	t.Run("Rejects a refresh token that was already used or revoked", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		refreshToken, refreshUuid := mintRefreshToken(t)

		mockRepo.On("FindById", uint64(1)).Return(&user.User{ID: 1}, nil)
		// 0 deleted keys: the session was already rotated out or revoked.
		mockRepo.On("RevokeSessionByRefresh", refreshUuid).Return(int64(0), nil)

		tokens, err := svc.Refresh(context.Background(), &user.RefreshInput{Refresh_token: refreshToken})

		assert.Error(t, err)
		assert.Nil(t, tokens)
		mockRepo.AssertNotCalled(t, "CreateAuth")
	})

	t.Run("Requires the pin when the account has pin auth enabled", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		refreshToken, _ := mintRefreshToken(t)

		mockRepo.On("FindById", uint64(1)).Return(&user.User{ID: 1, IsPinEnabled: true}, nil)

		tokens, err := svc.Refresh(context.Background(), &user.RefreshInput{Refresh_token: refreshToken})

		assert.Error(t, err)
		assert.Nil(t, tokens)
		mockRepo.AssertNotCalled(t, "RevokeSessionByRefresh")
	})
}

func TestDeleteAccount(t *testing.T) {
	t.Run("Purges the sessions and reset codes before deleting the row", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		hash, _ := bcrypt.GenerateFromPassword([]byte("Delete1234!"), bcrypt.MinCost)
		hashStr := string(hash)
		mockRepo.On("FindPasswordById", uint64(1)).Return(&hashStr, nil)
		mockRepo.On("RevokeAllSessions", uint64(1)).Return(nil)
		mockRepo.On("DeleteResetCodes", uint64(1)).Return(nil)
		mockRepo.On("Delete", uint64(1)).Return(nil)

		err := svc.DeleteAccount(context.Background(), "Delete1234!", 1)

		assert.NoError(t, err)
		mockRepo.AssertExpectations(t)
	})

	t.Run("Rejects a wrong password without touching anything", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		hash, _ := bcrypt.GenerateFromPassword([]byte("Delete1234!"), bcrypt.MinCost)
		hashStr := string(hash)
		mockRepo.On("FindPasswordById", uint64(1)).Return(&hashStr, nil)

		err := svc.DeleteAccount(context.Background(), "WrongPass123!", 1)

		assert.Error(t, err)
		assert.Equal(t, http.StatusUnauthorized, apperror.Status(err))
		mockRepo.AssertNotCalled(t, "RevokeAllSessions")
		mockRepo.AssertNotCalled(t, "DeleteResetCodes")
		mockRepo.AssertNotCalled(t, "Delete")
	})

	t.Run("Keeps the account when the session purge fails", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		hash, _ := bcrypt.GenerateFromPassword([]byte("Delete1234!"), bcrypt.MinCost)
		hashStr := string(hash)
		mockRepo.On("FindPasswordById", uint64(1)).Return(&hashStr, nil)
		mockRepo.On("RevokeAllSessions", uint64(1)).Return(errors.New("redis down"))

		err := svc.DeleteAccount(context.Background(), "Delete1234!", 1)

		assert.Error(t, err)
		mockRepo.AssertNotCalled(t, "Delete")
	})
}

func TestUpdatePassword(t *testing.T) {
	t.Run("Revokes every session before minting the new one", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		oldHash, _ := bcrypt.GenerateFromPassword([]byte("OldPass123!"), bcrypt.MinCost)
		oldHashStr := string(oldHash)
		mockRepo.On("FindPasswordById", uint64(1)).Return(&oldHashStr, nil)
		mockRepo.On("UpdatePassword", uint64(1), mock.AnythingOfType("string")).Return(nil)
		mockRepo.On("RevokeAllSessions", uint64(1)).Return(nil)
		mockRepo.On("CreateAuth", uint64(1), mock.AnythingOfType("*user.TokenDetails")).Return(nil)

		tokens, err := svc.UpdatePassword(context.Background(), "OldPass123!", "NewPass123!", 1)

		assert.NoError(t, err)
		assert.NotEmpty(t, tokens["access_token"])
		mockRepo.AssertExpectations(t)
	})

	t.Run("Rejects a wrong old password without touching sessions", func(t *testing.T) {
		mockRepo := new(mocks.MockUsersRepo)
		svc := application.NewUsersService(&application.UserConfig{UsersRepository: mockRepo, Tokens: testTokens})

		oldHash, _ := bcrypt.GenerateFromPassword([]byte("OldPass123!"), bcrypt.MinCost)
		oldHashStr := string(oldHash)
		mockRepo.On("FindPasswordById", uint64(1)).Return(&oldHashStr, nil)

		tokens, err := svc.UpdatePassword(context.Background(), "WrongPass!", "NewPass123!", 1)

		assert.Error(t, err)
		assert.Nil(t, tokens)
		mockRepo.AssertNotCalled(t, "RevokeAllSessions")
		mockRepo.AssertNotCalled(t, "UpdatePassword")
	})
}
