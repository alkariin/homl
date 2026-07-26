package mail

import (
	"io"
	"mime"
	"mime/quotedprintable"
	netmail "net/mail"
	"strings"
	"testing"
	"time"

	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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

func testMailer() *SMTPMailer {
	return &SMTPMailer{
		Host: "smtp.example.com",
		Port: "587",
		From: "no_reply@homl.ch",
	}
}

// sentAt is fixed so the Date header is assertable.
var sentAt = time.Date(2026, time.July, 26, 14, 30, 0, 0, time.UTC)

func TestBuildMessage(t *testing.T) {
	t.Run("Produces a parseable message with the mandatory headers", func(t *testing.T) {
		raw, err := testMailer().buildMessage("user@example.com", "123456", "en", sentAt)
		require.NoError(t, err)

		msg, err := netmail.ReadMessage(strings.NewReader(string(raw)))
		require.NoError(t, err)

		assert.Equal(t, "no_reply@homl.ch", msg.Header.Get("From"))
		assert.Equal(t, "user@example.com", msg.Header.Get("To"))
		assert.Equal(t, "Sun, 26 Jul 2026 14:30:00 +0000", msg.Header.Get("Date"))
		assert.Equal(t, "1.0", msg.Header.Get("MIME-Version"))
		assert.Equal(t, `text/plain; charset="UTF-8"`, msg.Header.Get("Content-Type"))
		assert.Equal(t, "quoted-printable", msg.Header.Get("Content-Transfer-Encoding"))

		// A Date the receiver can actually parse, not just a non-empty string.
		date, err := msg.Header.Date()
		require.NoError(t, err)
		assert.True(t, date.Equal(sentAt))
	})

	t.Run("Anchors the Message-ID to the sender domain and never repeats it", func(t *testing.T) {
		m := testMailer()

		first, err := m.buildMessage("user@example.com", "123456", "en", sentAt)
		require.NoError(t, err)
		second, err := m.buildMessage("user@example.com", "123456", "en", sentAt)
		require.NoError(t, err)

		idOf := func(raw []byte) string {
			msg, err := netmail.ReadMessage(strings.NewReader(string(raw)))
			require.NoError(t, err)
			return msg.Header.Get("Message-ID")
		}

		assert.True(t, strings.HasSuffix(idOf(first), "@homl.ch>"))
		assert.NotEqual(t, idOf(first), idOf(second))
	})

	t.Run("Falls back to the SMTP host when From carries no domain", func(t *testing.T) {
		m := testMailer()
		m.From = "no_reply"

		raw, err := m.buildMessage("user@example.com", "123456", "en", sentAt)
		require.NoError(t, err)
		assert.Contains(t, string(raw), "@smtp.example.com>")
	})

	t.Run("Keeps an ASCII subject unencoded", func(t *testing.T) {
		raw, err := testMailer().buildMessage("user@example.com", "123456", "en", sentAt)
		require.NoError(t, err)

		assert.Contains(t, string(raw), "Subject: Your HOML password reset code\r\n")
	})

	t.Run("MIME-encodes accented subjects instead of emitting raw UTF-8", func(t *testing.T) {
		for _, lang := range []user.Language{"fr", "de"} {
			raw, err := testMailer().buildMessage("user@example.com", "123456", lang, sentAt)
			require.NoError(t, err)

			subject := header(t, raw, "Subject")
			assert.Contains(t, subject, "=?utf-8?q?", "subject must be an encoded-word for %s", lang)

			// Every header byte stays 7-bit: raw UTF-8 in a header is what got
			// subjects mangled and scored as spam.
			headers, _, _ := strings.Cut(string(raw), "\r\n\r\n")
			for _, b := range []byte(headers) {
				require.Less(t, b, byte(128), "non-ASCII byte in headers for %s", lang)
			}

			decoded, err := new(mime.WordDecoder).DecodeHeader(subject)
			require.NoError(t, err)
			assert.Equal(t, resetCodeTemplates[lang].subject, decoded)
		}
	})

	t.Run("Carries the code in a decodable body", func(t *testing.T) {
		for _, lang := range []user.Language{"en", "fr", "de"} {
			raw, err := testMailer().buildMessage("user@example.com", "424242", lang, sentAt)
			require.NoError(t, err)

			_, encodedBody, found := strings.Cut(string(raw), "\r\n\r\n")
			require.True(t, found)

			body, err := io.ReadAll(quotedprintable.NewReader(strings.NewReader(encodedBody)))
			require.NoError(t, err)
			assert.Contains(t, string(body), "424242")
			assert.Contains(t, string(body), "15")
		}
	})
}

// header extracts one header value through a real message parse.
func header(t *testing.T, raw []byte, name string) string {
	t.Helper()
	msg, err := netmail.ReadMessage(strings.NewReader(string(raw)))
	require.NoError(t, err)
	return msg.Header.Get(name)
}
