package mail

import (
	"log"

	"github.com/alkariin/homl/homl-web/internal/domain/user"
)

// LogMailer writes emails to the application log instead of sending them.
// Used in DEV or when SMTP is not configured.
type LogMailer struct{}

func (m *LogMailer) SendPasswordResetCode(to string, code string, language user.Language) error {
	log.Printf("DEV mailer: password reset code for %s (lang %s): %s", to, language, code)
	return nil
}
