package application

import (
	"strings"
	"unicode"
)

// titleCase upper-cases the first letter of every word, matching what the
// services previously relied on from the deprecated strings.Title. A word
// starts after any non-letter/non-digit rune, which covers the names and tag
// labels this codebase feeds it ("jean-pierre" -> "Jean-Pierre").
func titleCase(s string) string {
	prev := ' '
	return strings.Map(func(r rune) rune {
		if !unicode.IsLetter(prev) && !unicode.IsDigit(prev) {
			prev = r
			return unicode.ToTitle(r)
		}
		prev = r
		return r
	}, s)
}
