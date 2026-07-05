package web

import (
	"log"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/gin-gonic/gin"
	"gopkg.in/go-playground/validator.v8"
)

var validate *validator.Validate

func init() {
	config := &validator.Config{TagName: "validate"}
	validate = validator.New(config)
}

func SendGinMyCustomError(c *gin.Context, err error, replacedError *apperror.Error) {
	log.Printf("Not app error: " + err.Error())
	SendGinError(c, replacedError)
}

func SendGinError(c *gin.Context, err error) {
	// create the helper.Error
	var resultError *apperror.Error
	e := apperror.IsError(err)
	if e == nil {
		// replace by empty message, don't give any info
		log.Printf("Not app error: " + err.Error())
		resultError = apperror.NewInternal()
	} else {
		resultError = e
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
		err := validate.Field(param.Field, param.Validation)
		if err != nil {
			return true
		}
	}
	return false
}

func CheckGinInputStruct(object interface{}) error {
	return validate.Struct(object)
}
