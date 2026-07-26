package mail

import (
	"log"

	"github.com/alkariin/homl/homl-web/internal/domain/user"
)

// maxConcurrentSends caps how many SMTP conversations run at once. The reset
// endpoints are already throttled (5/hour per IP, 1 min per account), so this
// is a backstop against a slow server accumulating goroutines, not a queue.
const maxConcurrentSends = 8

// resetCodeSender is the slice of the application Mailer port that AsyncMailer
// decorates. Declared here so infrastructure keeps depending only on the
// domain.
type resetCodeSender interface {
	SendPasswordResetCode(to string, code string, language user.Language) error
}

// AsyncMailer hands sending off to a background goroutine and reports success
// immediately.
//
// The reset code is emailed while handling the request, which answers 204
// whether or not the account exists. Sending inline breaks both halves of that
// promise as soon as the submission server is slow: it trips the handler
// timeout, turning the unconditional 204 into a 503, and it makes response time
// depend on whether the address was found — the exact enumeration signal the
// flow is designed to withhold. Detaching the send keeps the response
// constant-status and constant-time.
//
// Delivery errors are logged, never returned: the caller must not learn
// whether an address is deliverable. The trade-off is that a send in flight is
// lost if the process stops.
type AsyncMailer struct {
	mailer   resetCodeSender
	inFlight chan struct{}
}

func NewAsyncMailer(mailer resetCodeSender) *AsyncMailer {
	return &AsyncMailer{
		mailer:   mailer,
		inFlight: make(chan struct{}, maxConcurrentSends),
	}
}

func (m *AsyncMailer) SendPasswordResetCode(to string, code string, language user.Language) error {
	go func() {
		m.inFlight <- struct{}{}
		defer func() { <-m.inFlight }()

		// Never log the recipient: a reset log must not become a directory of
		// which addresses hold an account.
		if err := m.mailer.SendPasswordResetCode(to, code, language); err != nil {
			log.Printf("mail: could not send password reset code: %v", err)
		}
	}()

	return nil
}
