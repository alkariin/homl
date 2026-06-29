package model

import "time"

type Event struct {
	Id          uint      `json:"id"`
	Description string    `json:"description"`
	Date        time.Time `json:"date"` // type date doesn't exist in go
}

type GetEventsResponse struct {
	Event
	Tags []Tag `json:"tags"`
}
