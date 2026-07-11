package mail

import (
	"testing"

	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/stretchr/testify/assert"
)

func TestTemplateFor(t *testing.T) {
	t.Run("Returns the template matching the user language", func(t *testing.T) {
		for _, lang := range []user.Language{"en", "fr", "de"} {
			tpl := templateFor(lang)
			assert.Equal(t, resetCodeTemplates[lang], tpl)
			assert.NotEmpty(t, tpl.subject)
			assert.Contains(t, tpl.body, "%s")
		}
	})

	t.Run("Falls back to English for unknown languages", func(t *testing.T) {
		assert.Equal(t, resetCodeTemplates["en"], templateFor("it"))
		assert.Equal(t, resetCodeTemplates["en"], templateFor(""))
	})
}
