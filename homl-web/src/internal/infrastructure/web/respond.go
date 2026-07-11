package web

import (
	"errors"
	"log"
	"net/http"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
)

var validate *validator.Validate

func init() {
	validate = validator.New(validator.WithRequiredStructEnabled())
	validate.SetTagName("validate")
}

// SendGinMyCustomError responds with replacedError, keeping the technical
// cause in the server log only. Body-size violations are mapped to a 413
// instead, so the client knows the payload (not its content) was the problem.
func SendGinMyCustomError(c *gin.Context, err error, replacedError *apperror.Error) {
	log.Printf("Not app error: %s", err.Error())

	var maxBytesErr *http.MaxBytesError
	if errors.As(err, &maxBytesErr) {
		SendGinError(c, apperror.NewPayloadTooLarge(maxBytesErr.Limit, c.Request.ContentLength))
		return
	}

	SendGinError(c, replacedError)
}

func SendGinError(c *gin.Context, err error) {
	// create the helper.Error
	var resultError *apperror.Error
	if !errors.As(err, &resultError) {
		// replace by empty message, don't give any info
		log.Printf("Not app error: %s", err.Error())
		resultError = apperror.NewInternal()
	}

	// return gin error
	c.JSON(resultError.Status(), gin.H{
		"error": resultError,
	})
}

type GinInputParams struct {
	Field      interface{}
	Validation string
}

func CheckGinInput(params ...GinInputParams) bool {
	for _, param := range params {
		err := validate.Var(param.Field, param.Validation)
		if err != nil {
			return true
		}
	}
	return false
}

func CheckGinInputStruct(object interface{}) error {
	return validate.Struct(object)
}
