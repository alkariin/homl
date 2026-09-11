package event_test

import (
	"testing"
	"time"

	"github.com/alkariin/homl/homl-web/internal/domain/event"
	"github.com/stretchr/testify/assert"
)

func day(y int, m time.Month, d int) time.Time {
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

func ptr(t time.Time) *time.Time { return &t }

var everyMonth = []string{
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
}

// The shared vectors of the period design (§5.4): the Flutter client builds
// the very same tags for E2EE accounts, and its test table must stay
// identical to this one. The names are compared as sets — EventsTags has no
// order, so pinning one would only manufacture false failures between the
// two implementations.
func TestDateTagNames(t *testing.T) {
	cases := []struct {
		name string
		evt  event.Event
		want []string
	}{
		{
			name: "single day",
			evt:  event.Event{Date: day(2026, time.June, 3)},
			want: []string{"June", "2026"},
		},
		{
			name: "closed, same month",
			evt:  event.Event{Date: day(2026, time.June, 3), EndDate: ptr(day(2026, time.June, 18))},
			want: []string{"June", "2026"},
		},
		{
			name: "closed, two months",
			evt:  event.Event{Date: day(2026, time.June, 28), EndDate: ptr(day(2026, time.July, 5))},
			want: []string{"June", "July", "2026"},
		},
		{
			name: "closed, year boundary",
			evt:  event.Event{Date: day(2025, time.December, 28), EndDate: ptr(day(2026, time.January, 5))},
			want: []string{"December", "January", "2025", "2026"},
		},
		{
			name: "closed, over a year",
			evt:  event.Event{Date: day(2024, time.March, 1), EndDate: ptr(day(2026, time.August, 31))},
			want: append(append([]string{}, everyMonth...), "2024", "2025", "2026"),
		},
		{
			// An open period has no known end: tagged from its start only,
			// never expanded to "today" (design §5.3), plus the Ongoing tag.
			name: "open",
			evt:  event.Event{Date: day(2024, time.June, 3), IsOngoing: true},
			want: []string{"June", "2024", event.OngoingTag},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			assert.ElementsMatch(t, tc.want, tc.evt.DateTagNames())
		})
	}
}

// A start on the 31st must not skip February on its way to March: adding a
// month to 31 January lands in March, so the walk has to pin the day.
func TestDateTagNamesStartingOnAMonthEnd(t *testing.T) {
	evt := event.Event{Date: day(2026, time.January, 31), EndDate: ptr(day(2026, time.March, 1))}

	assert.ElementsMatch(t, []string{"January", "February", "March", "2026"}, evt.DateTagNames())
}
