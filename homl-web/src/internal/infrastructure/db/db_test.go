package db

import (
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

// A data source that refuses a few connections (MySQL still starting while
// the host boots) is waited for, not given up on.
func TestRetryWaitsForTheDataSource(t *testing.T) {
	refused := errors.New("connection refused")
	calls := 0
	err := retry("MySQL", time.Second, time.Millisecond, 4*time.Millisecond, func() error {
		calls++
		if calls < 4 {
			return refused
		}
		return nil
	})

	assert.NoError(t, err)
	assert.Equal(t, 4, calls)
}

// A data source that never answers fails startup once the time is up, with
// the last error, so a wrong address or password still surfaces.
func TestRetryGivesUpWithTheLastError(t *testing.T) {
	calls := 0
	err := retry("Redis", 30*time.Millisecond, time.Millisecond, 4*time.Millisecond, func() error {
		calls++
		return errors.New("WRONGPASS")
	})

	assert.EqualError(t, err, "WRONGPASS")
	assert.Greater(t, calls, 1)
}

func TestRetrySucceedsAtOnceWithoutWaiting(t *testing.T) {
	start := time.Now()
	err := retry("MySQL", time.Minute, time.Second, time.Second, func() error { return nil })

	assert.NoError(t, err)
	assert.Less(t, time.Since(start), 500*time.Millisecond) // no 1 s sleep first
}
