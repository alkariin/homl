package mail

import "log"

// LogMailer writes emails to the application log instead of sending them.
// Used in DEV or when SMTP is not configured.
type LogMailer struct{}

func (m *LogMailer) SendPasswordResetCode(to string, code string) error {
	log.Printf("DEV mailer: password reset code for %s: %s", to, code)
	return nil
}
