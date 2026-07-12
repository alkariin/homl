package application

import (
	"strings"
	"unicode"
)

// titleCase upper-cases the first letter of every word and lower-cases the
// rest ("MOVIE night" -> "Movie Night"). Tags are matched by deterministic
// encryption, so the exact same normalization must run on both the write path
// and the search path for lookups to hit regardless of the typed casing. A
// word starts after any non-letter/non-digit rune, which covers the names and
// tag labels this codebase feeds it ("jean-pierre" -> "Jean-Pierre").
func titleCase(s string) string {
	prev := ' '
	return strings.Map(func(r rune) rune {
		first := !unicode.IsLetter(prev) && !unicode.IsDigit(prev)
		prev = r
		if first {
			return unicode.ToTitle(r)
		}
		return unicode.ToLower(r)
	}, s)
}
