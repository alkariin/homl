// Package version exposes the build identity of the running binary.
package version

// Version is the git describe output of the commit the binary was built from
// ("v0.1.0", "v0.1.0-3-gabc1234", "v0.1.0-dirty"). It is injected at build
// time with
//
//	go build -ldflags "-X github.com/alkariin/homl/homl-web/internal/version.Version=v0.1.0"
//
// — the Dockerfiles do it from their VERSION build arg, the Makefile from
// `git describe`. A plain `go run .` leaves the default, so a "dev" in the
// logs or in /healthz means an untagged, local build.
var Version = "dev"
