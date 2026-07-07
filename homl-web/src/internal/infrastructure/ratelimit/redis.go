// Package ratelimit is the infrastructure adapter for request rate limiting.
// It implements the web.RateLimiter port on top of Redis, so counters survive
// restarts and are shared across instances.
package ratelimit

import (
	"time"

	"github.com/go-redis/redis/v7"
)

// RedisLimiter implements a fixed-window counter in Redis.
type RedisLimiter struct {
	client *redis.Client
}

func NewRedisLimiter(client *redis.Client) *RedisLimiter {
	return &RedisLimiter{client: client}
}

// allowScript increments the counter and sets the window expiry in one atomic
// step. Doing INCR and EXPIRE as two separate commands could leave a counter
// without expiry (e.g. process dies in between), permanently locking the key.
var allowScript = redis.NewScript(`
	local count = redis.call('INCR', KEYS[1])
	if count == 1 then
		redis.call('PEXPIRE', KEYS[1], ARGV[1])
	end
	return count
`)

// Allow increments the counter for key and reports whether it stays within
// limit for the current window. Only the first hit of a window sets the expiry,
// so the window is fixed and resets once it elapses.
func (r *RedisLimiter) Allow(key string, limit int, window time.Duration) (bool, error) {
	count, err := allowScript.Run(r.client, []string{key}, window.Milliseconds()).Int64()
	if err != nil {
		return false, err
	}
	return count <= int64(limit), nil
}
