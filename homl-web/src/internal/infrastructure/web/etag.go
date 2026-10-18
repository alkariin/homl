package web

import (
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// ETag answers a read with a fingerprint of its body, and with 304 Not
// Modified — no body at all — when the client sends that fingerprint back
// in If-None-Match: it already holds that very body. The app keeps the last
// body of each read with its ETag (homl-ui LocalStore), so a refresh where
// nothing changed costs one request and no data (docs/api.md, "Conditional
// reads").
//
// The body is still built every time: nothing tracks the writes, the
// fingerprint is of what would be sent, so a change can never be missed —
// any write, any cascade, any re-encryption changes the bytes. The reads
// it wraps are deterministic (sorted events, ORDER BY on tags and groups),
// so the same data always gives the same fingerprint.
//
// Only a 200 gets one; any other answer passes through untouched. The
// response also says Cache-Control: no-store — the personal data must not
// land in a browser cache in clear, the app keeps its own sealed copy.
func ETag() gin.HandlerFunc {
	return func(c *gin.Context) {
		buffered := &bufferedWriter{ResponseWriter: c.Writer, status: http.StatusOK}
		c.Writer = buffered
		c.Next()
		c.Writer = buffered.ResponseWriter

		if buffered.status != http.StatusOK {
			c.Writer.WriteHeader(buffered.status)
			_, _ = c.Writer.Write(buffered.body.Bytes())
			return
		}

		sum := sha256.Sum256(buffered.body.Bytes())
		etag := `"` + base64.RawURLEncoding.EncodeToString(sum[:18]) + `"`
		c.Writer.Header().Set("ETag", etag)
		c.Writer.Header().Set("Cache-Control", "no-store")
		if etagMatches(c.GetHeader("If-None-Match"), etag) {
			c.Writer.WriteHeader(http.StatusNotModified)
			return
		}
		c.Writer.WriteHeader(http.StatusOK)
		_, _ = c.Writer.Write(buffered.body.Bytes())
	}
}

// etagMatches reports whether an If-None-Match value names etag: a list of
// tags, weak ones (W/) compared on their opaque part, or "*".
func etagMatches(ifNoneMatch, etag string) bool {
	for _, candidate := range strings.Split(ifNoneMatch, ",") {
		candidate = strings.TrimPrefix(strings.TrimSpace(candidate), "W/")
		if candidate == "*" || candidate == etag {
			return true
		}
	}
	return false
}

// bufferedWriter holds the handler's answer back until the fingerprint is
// known: the status and the body are kept, the headers go straight to the
// wrapped writer.
type bufferedWriter struct {
	gin.ResponseWriter
	status int
	body   bytes.Buffer
}

func (w *bufferedWriter) WriteHeader(code int) { w.status = code }

func (w *bufferedWriter) WriteHeaderNow() {}

func (w *bufferedWriter) Write(data []byte) (int, error) { return w.body.Write(data) }

func (w *bufferedWriter) WriteString(s string) (int, error) { return w.body.WriteString(s) }

func (w *bufferedWriter) Status() int { return w.status }

func (w *bufferedWriter) Size() int { return w.body.Len() }

func (w *bufferedWriter) Written() bool { return w.body.Len() > 0 }
