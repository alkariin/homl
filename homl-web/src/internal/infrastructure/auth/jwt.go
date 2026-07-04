// Package auth is the infrastructure adapter for JWT-based authentication.
// It implements the application.TokenIssuer port (minting/verifying token
// pairs) and the web.TokenParser port (reading tokens off incoming requests).
package auth

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/twinj/uuid"

	"github.com/alkariin/homl/homl-web/internal/domain/user"
)

var ACCESS_TOKEN_EXPIRE_MINUTES = 10
var REFRESH_TOKEN_EXPIRE_MINUTES = 60 * 24 * 365 / 2 // 6 months

type JWT struct {
	accessSecret  string
	refreshSecret string
	dev           bool // dev tokens live one year to ease local debugging
}

func NewJWT(accessSecret string, refreshSecret string, dev bool) *JWT {
	return &JWT{
		accessSecret:  accessSecret,
		refreshSecret: refreshSecret,
		dev:           dev,
	}
}

func (j *JWT) CreateToken(userid uint64) (*user.TokenDetails, error) {
	td := &user.TokenDetails{}
	var tokenExpiresMin int
	if j.dev {
		tokenExpiresMin = 525600 // 1 year
	} else {
		tokenExpiresMin = ACCESS_TOKEN_EXPIRE_MINUTES
	}
	td.AtExpires = time.Now().Add(time.Minute * time.Duration(tokenExpiresMin)).Unix()
	td.AccessUuid = uuid.NewV4().String()

	td.RtExpires = time.Now().Add(time.Minute * time.Duration(REFRESH_TOKEN_EXPIRE_MINUTES)).Unix()
	td.RefreshUuid = uuid.NewV4().String()

	var err error
	//Creating Access Token
	atClaims := jwt.MapClaims{}
	atClaims["authorized"] = true
	atClaims["access_uuid"] = td.AccessUuid
	atClaims["user_id"] = userid
	atClaims["exp"] = td.AtExpires
	at := jwt.NewWithClaims(jwt.SigningMethodHS256, atClaims)
	td.AccessToken, err = at.SignedString([]byte(j.accessSecret))
	if err != nil {
		return nil, err
	}
	//Creating Refresh Token
	rtClaims := jwt.MapClaims{}
	rtClaims["refresh_uuid"] = td.RefreshUuid
	rtClaims["user_id"] = userid
	rtClaims["exp"] = td.RtExpires
	rt := jwt.NewWithClaims(jwt.SigningMethodHS256, rtClaims)
	td.RefreshToken, err = rt.SignedString([]byte(j.refreshSecret))
	if err != nil {
		return nil, err
	}
	return td, nil
}

// VerifyRefresh checks the signature and validity of a refresh token and
// returns its typed metadata, so the application layer never touches claims.
func (j *JWT) VerifyRefresh(refreshToken string) (*user.RefreshDetails, error) {
	token, err := jwt.Parse(refreshToken, func(token *jwt.Token) (interface{}, error) {
		//Make sure that the token method conform to "SigningMethodHMAC"
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(j.refreshSecret), nil
	})
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid refresh token")
	}

	refreshUuid, ok := claims["refresh_uuid"].(string)
	if !ok {
		return nil, fmt.Errorf("refresh token misses refresh_uuid claim")
	}
	userId, err := strconv.ParseUint(fmt.Sprintf("%.f", claims["user_id"]), 10, 64)
	if err != nil {
		return nil, err
	}

	return &user.RefreshDetails{
		RefreshUuid: refreshUuid,
		UserId:      userId,
	}, nil
}

func extractToken(r *http.Request) string {
	bearToken := r.Header.Get("Authorization")
	//normally Authorization the_token_xxx
	strArr := strings.Split(bearToken, " ")
	if len(strArr) == 2 {
		return strArr[1]
	}
	return ""
}

func (j *JWT) verifyToken(r *http.Request) (*jwt.Token, error) {
	tokenString := extractToken(r)
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		//Make sure that the token method conform to "SigningMethodHMAC"
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(j.accessSecret), nil
	})
	if err != nil {
		return nil, err
	}
	return token, nil
}

// Valid reports whether the request carries a valid access token.
func (j *JWT) Valid(r *http.Request) error {
	token, err := j.verifyToken(r)
	if err != nil {
		return err
	}
	if _, ok := token.Claims.(jwt.Claims); !ok && !token.Valid {
		return err
	}
	return nil
}

// ExtractAccessDetails parses the request's access token and returns its
// session metadata.
func (j *JWT) ExtractAccessDetails(r *http.Request) (*user.AccessDetails, error) {
	token, err := j.verifyToken(r)
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if ok && token.Valid {
		accessUuid, ok := claims["access_uuid"].(string)
		if !ok {
			return nil, fmt.Errorf("access token misses access_uuid claim")
		}
		userId, err := strconv.ParseUint(fmt.Sprintf("%.f", claims["user_id"]), 10, 64)
		if err != nil {
			return nil, err
		}
		return &user.AccessDetails{
			AccessUuid: accessUuid,
			UserId:     userId,
		}, nil
	}
	return nil, fmt.Errorf("invalid access token")
}
