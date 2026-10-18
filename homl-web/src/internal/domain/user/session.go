package user

import (
	"context"
	"time"
)

// SessionInfo is what a request says about its client, recorded on the
// device session it opens or renews: what the app calls itself — its
// platform and version, the X-Homl-Client header — and the address it
// connected from.
type SessionInfo struct {
	Client string
	IP     string
}

// Session is one signed-in device: a login (or a registration, a password
// change or reset) and every refresh that followed it. Its tokens change at
// each refresh; its id does not.
type Session struct {
	Id     string `json:"id"`
	Client string `json:"client"`
	IP     string `json:"ip"`
	// CreatedAt is nil for a session opened before devices were recorded:
	// it was taken in at its first refresh since, its login time unknown.
	CreatedAt  *time.Time `json:"createdAt"`
	LastSeenAt time.Time  `json:"lastSeenAt"`
	// Current marks the session of the request that listed them.
	Current bool `json:"current"`
}

type sessionInfoKey struct{}

// WithSessionInfo carries info in ctx, set once per request by the web layer.
func WithSessionInfo(ctx context.Context, info SessionInfo) context.Context {
	return context.WithValue(ctx, sessionInfoKey{}, info)
}

// SessionInfoFrom returns the SessionInfo carried in ctx, or a blank one.
func SessionInfoFrom(ctx context.Context) SessionInfo {
	info, _ := ctx.Value(sessionInfoKey{}).(SessionInfo)
	return info
}
