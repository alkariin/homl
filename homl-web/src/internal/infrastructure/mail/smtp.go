// Package mail provides the outgoing-email adapters behind the application
// Mailer port.
package mail

import (
	"bytes"
	"crypto/rand"
	"crypto/tls"
	"encoding/hex"
	"fmt"
	"mime"
	"mime/quotedprintable"
	"net"
	"net/smtp"
	"strings"
	"time"

	"github.com/alkariin/homl/homl-web/internal/domain/user"
)

// smtpTimeout bounds the whole submission exchange (dial, handshake, auth,
// data). net/smtp has no timeout of its own, so without this a hung server
// would pin the sending goroutine indefinitely.
const smtpTimeout = 10 * time.Second

// implicitTLSPort is the submission port that expects TLS from the first byte
// ("SMTPS"), as opposed to STARTTLS upgrades on 587/25.
const implicitTLSPort = "465"

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

// SMTPMailer sends transactional emails through an SMTP submission server.
// Both submission modes are covered: STARTTLS upgrades (typically port 587)
// and implicit TLS (port 465, which net/smtp cannot dial on its own).
type SMTPMailer struct {
	Host string
	Port string
	From string
	// User is the authentication identity. It falls back to From, which only
	// matches mailbox providers: API-style relays want their own username
	// (SendGrid "apikey", SES IAM credentials, Mailgun postmaster@domain).
	User string
	// Password empty disables authentication entirely, for local relays and
	// mail catchers that accept anonymous submission.
	Password string
}

func (m *SMTPMailer) SendPasswordResetCode(to string, code string, language user.Language) error {
	message, err := m.buildMessage(to, code, language, time.Now())
	if err != nil {
		return err
	}
	return m.send(to, message)
}

// buildMessage renders the RFC 5322 message carrying a reset code. The subject
// becomes a MIME encoded-word and the body quoted-printable, so the accented
// French and German templates survive servers that do not announce 8BITMIME
// (raw UTF-8 in a header is non-conformant, and gets either mangled or scored
// as spam).
func (m *SMTPMailer) buildMessage(to string, code string, language user.Language, now time.Time) ([]byte, error) {
	t := templateFor(language)

	messageID, err := m.messageID()
	if err != nil {
		return nil, err
	}

	var body bytes.Buffer
	qp := quotedprintable.NewWriter(&body)
	if _, err := qp.Write([]byte(fmt.Sprintf(t.body, code))); err != nil {
		return nil, err
	}
	if err := qp.Close(); err != nil {
		return nil, err
	}

	headers := []string{
		"From: " + m.From,
		"To: " + to,
		"Subject: " + mime.QEncoding.Encode("utf-8", t.subject),
		// Date and Message-ID are mandatory in practice: their absence is a
		// well-known spam signal (SpamAssassin MISSING_DATE / MISSING_MID).
		"Date: " + now.Format(time.RFC1123Z),
		"Message-ID: " + messageID,
		"MIME-Version: 1.0",
		`Content-Type: text/plain; charset="UTF-8"`,
		"Content-Transfer-Encoding: quoted-printable",
	}

	return []byte(strings.Join(headers, "\r\n") + "\r\n\r\n" + body.String()), nil
}

// messageID returns a unique Message-ID anchored to the sender's domain.
func (m *SMTPMailer) messageID() (string, error) {
	unique := make([]byte, 16)
	if _, err := rand.Read(unique); err != nil {
		return "", err
	}

	domain := m.Host
	if _, fromDomain, found := strings.Cut(m.From, "@"); found {
		domain = fromDomain
	}

	return "<" + hex.EncodeToString(unique) + "@" + domain + ">", nil
}

// send delivers the message over a connection whose entire lifetime is capped
// by a single deadline.
func (m *SMTPMailer) send(to string, message []byte) error {
	address := net.JoinHostPort(m.Host, m.Port)
	dialer := &net.Dialer{Timeout: smtpTimeout}
	tlsConfig := &tls.Config{ServerName: m.Host}

	implicitTLS := m.Port == implicitTLSPort
	var conn net.Conn
	var err error
	if implicitTLS {
		conn, err = tls.DialWithDialer(dialer, "tcp", address, tlsConfig)
	} else {
		conn, err = dialer.Dial("tcp", address)
	}
	if err != nil {
		return err
	}
	defer conn.Close()

	if err := conn.SetDeadline(time.Now().Add(smtpTimeout)); err != nil {
		return err
	}

	client, err := smtp.NewClient(conn, m.Host)
	if err != nil {
		return err
	}
	defer client.Close()

	if !implicitTLS {
		if ok, _ := client.Extension("STARTTLS"); ok {
			if err := client.StartTLS(tlsConfig); err != nil {
				return err
			}
		}
	}

	// PlainAuth refuses to hand credentials to a cleartext connection, so a
	// server that advertises no STARTTLS fails closed here rather than leaking
	// the password.
	if m.Password != "" {
		authUser := m.User
		if authUser == "" {
			authUser = m.From
		}
		if err := client.Auth(smtp.PlainAuth("", authUser, m.Password, m.Host)); err != nil {
			return err
		}
	}

	if err := client.Mail(m.From); err != nil {
		return err
	}
	if err := client.Rcpt(to); err != nil {
		return err
	}

	writer, err := client.Data()
	if err != nil {
		return err
	}
	if _, err := writer.Write(message); err != nil {
		return err
	}
	if err := writer.Close(); err != nil {
		return err
	}

	return client.Quit()
}
