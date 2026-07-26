package mail

import (
	"errors"
	"sync/atomic"
	"testing"
	"time"

	"github.com/alkariin/homl/homl-web/internal/domain/user"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// blockingSender stands in for a submission server that never answers.
type blockingSender struct {
	started  chan struct{}
	release  chan struct{}
	attempts atomic.Int32
}

func newBlockingSender() *blockingSender {
	return &blockingSender{
		started: make(chan struct{}, maxConcurrentSends),
		release: make(chan struct{}),
	}
}

func (s *blockingSender) SendPasswordResetCode(to string, code string, language user.Language) error {
	s.attempts.Add(1)
	s.started <- struct{}{}
	<-s.release
	return errors.New("smtp unreachable")
}

func TestAsyncMailer(t *testing.T) {
	t.Run("Returns before the underlying send completes", func(t *testing.T) {
		sender := newBlockingSender()
		defer close(sender.release)

		done := make(chan error, 1)
		go func() {
			done <- NewAsyncMailer(sender).SendPasswordResetCode("user@example.com", "123456", "fr")
		}()

		select {
		case err := <-done:
			// The caller must not wait on the server, and must not learn that
			// delivery failed — that is what keeps the 204 unconditional.
			assert.NoError(t, err)
		case <-time.After(2 * time.Second):
			t.Fatal("SendPasswordResetCode blocked on the underlying mailer")
		}

		// The send really was attempted, just not inline.
		select {
		case <-sender.started:
		case <-time.After(2 * time.Second):
			t.Fatal("the underlying mailer was never called")
		}
	})

	t.Run("Forwards the recipient, code and language untouched", func(t *testing.T) {
		received := make(chan [3]string, 1)
		mailer := NewAsyncMailer(senderFunc(func(to string, code string, language user.Language) error {
			received <- [3]string{to, code, string(language)}
			return nil
		}))

		require.NoError(t, mailer.SendPasswordResetCode("user@example.com", "123456", "de"))

		select {
		case got := <-received:
			assert.Equal(t, [3]string{"user@example.com", "123456", "de"}, got)
		case <-time.After(2 * time.Second):
			t.Fatal("the underlying mailer was never called")
		}
	})

	t.Run("Caps concurrent sends when the server hangs", func(t *testing.T) {
		sender := newBlockingSender()
		defer close(sender.release)
		mailer := NewAsyncMailer(sender)

		for range maxConcurrentSends + 4 {
			require.NoError(t, mailer.SendPasswordResetCode("user@example.com", "123456", "en"))
		}

		// Drain exactly the slots the semaphore should allow.
		for range maxConcurrentSends {
			select {
			case <-sender.started:
			case <-time.After(2 * time.Second):
				t.Fatal("fewer sends started than the concurrency cap allows")
			}
		}

		// The extra calls are queued, not running: nothing else may start
		// while the in-flight sends still hold every slot.
		select {
		case <-sender.started:
			t.Fatal("more sends ran concurrently than maxConcurrentSends")
		case <-time.After(100 * time.Millisecond):
		}

		assert.LessOrEqual(t, int(sender.attempts.Load()), maxConcurrentSends)
	})
}

// senderFunc adapts a function to the resetCodeSender port.
type senderFunc func(to string, code string, language user.Language) error

func (f senderFunc) SendPasswordResetCode(to string, code string, language user.Language) error {
	return f(to, code, language)
}
