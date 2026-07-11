// Package mail provides the outgoing-email adapters behind the application
// Mailer port.
package mail

import (
	"fmt"
	"net/smtp"

	"github.com/alkariin/homl/homl-web/internal/domain/user"
)

// resetCodeTemplate holds the localized subject and body of the
// password-reset email. The body expects the code as its single argument.
type resetCodeTemplate struct {
	subject string
	body    string
}

// resetCodeTemplates maps the user's stored language to its email template.
// English is the fallback for unknown or missing languages.
var resetCodeTemplates = map[user.Language]resetCodeTemplate{
	"en": {
		subject: "Your HOML password reset code",
		body:    "Your password reset code is: %s\r\nIt expires in 15 minutes.\r\n",
	},
	"fr": {
		subject: "Votre code de réinitialisation HOML",
		body:    "Votre code de réinitialisation est : %s\r\nIl expire dans 15 minutes.\r\n",
	},
	"de": {
		subject: "Ihr HOML-Code zum Zurücksetzen des Passworts",
		body:    "Ihr Code zum Zurücksetzen des Passworts lautet: %s\r\nEr läuft in 15 Minuten ab.\r\n",
	},
}

// templateFor resolves the email template for a language, falling back to
// English.
func templateFor(language user.Language) resetCodeTemplate {
	if t, ok := resetCodeTemplates[language]; ok {
		return t
	}
	return resetCodeTemplates["en"]
}

// SMTPMailer sends transactional emails through a plain-auth SMTP server.
type SMTPMailer struct {
	Host     string
	Port     string
	From     string
	Password string
}

func (m *SMTPMailer) SendPasswordResetCode(to string, code string, language user.Language) error {
	t := templateFor(language)
	message := []byte(fmt.Sprintf(
		"From: %s\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n"+t.body,
		m.From, to, t.subject, code))
	auth := smtp.PlainAuth("", m.From, m.Password, m.Host)
	return smtp.SendMail(m.Host+":"+m.Port, auth, m.From, []string{to}, message)
}
