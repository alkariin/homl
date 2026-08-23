package web

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// slowRouter serves one route that answers after handlerWork, optionally
// behind the Deadlines middleware. It is meant to run on a server whose write
// timeout is far shorter than that work — the shape of the real setup, where
// main.go caps every connection at 20 s while the E2EE migration is granted
// 60 s.
func slowRouter(withDeadlines bool, handlerWork time.Duration) *gin.Engine {
	r := gin.New()
	g := r.Group("/")
	if withDeadlines {
		g.Use(Deadlines(5*time.Second, 5*time.Second))
	}
	g.Use(Timeout(5*time.Second, apperror.NewServiceUnavailable()))
	g.GET("/slow", func(c *gin.Context) {
		time.Sleep(handlerWork)
		c.JSON(http.StatusOK, gin.H{"done": true})
	})
	return r
}

func serveWithWriteTimeout(t *testing.T, r *gin.Engine, writeTimeout time.Duration) *httptest.Server {
	t.Helper()
	srv := httptest.NewUnstartedServer(r)
	srv.Config.ReadTimeout = writeTimeout
	srv.Config.WriteTimeout = writeTimeout
	srv.Start()
	t.Cleanup(srv.Close)
	return srv
}

// The server-wide write timeout is an absolute connection deadline: the
// per-handler Timeout middleware cannot lift it on its own, so a route that
// legitimately needs longer (the E2EE migration) has to raise the deadline
// itself. This asserts the cap really is in force without the middleware...
func TestServerWriteTimeoutCutsALongHandler(t *testing.T) {
	srv := serveWithWriteTimeout(t, slowRouter(false, 400*time.Millisecond), 100*time.Millisecond)

	_, err := http.Get(srv.URL + "/slow")

	assert.Error(t, err, "the connection should be dropped before the handler answers")
}

// ...and that Deadlines lifts it, which is what keeps the migration's 60 s
// budget real.
func TestDeadlinesLiftsTheServerWriteTimeout(t *testing.T) {
	srv := serveWithWriteTimeout(t, slowRouter(true, 400*time.Millisecond), 100*time.Millisecond)

	resp, err := http.Get(srv.URL + "/slow")

	require.NoError(t, err)
	defer resp.Body.Close()
	assert.Equal(t, http.StatusOK, resp.StatusCode)
}
