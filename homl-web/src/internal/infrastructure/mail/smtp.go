// Package mail provides the outgoing-email adapters behind the application
// Mailer port.
package mail

import (
	"fmt"
	"net/smtp"
)

// SMTPMailer sends transactional emails through a plain-auth SMTP server.
type SMTPMailer struct {
	Host     string
	Port     string
	From     string
	Password string
}

func (m *SMTPMailer) SendPasswordResetCode(to string, code string) error {
	message := []byte(fmt.Sprintf(
		"From: %s\r\nTo: %s\r\nSubject: Your HOML password reset code\r\n\r\n"+
			"Your password reset code is: %s\r\nIt expires in 15 minutes.\r\n",
		m.From, to, code))
	auth := smtp.PlainAuth("", m.From, m.Password, m.Host)
	return smtp.SendMail(m.Host+":"+m.Port, auth, m.From, []string{to}, message)
}
