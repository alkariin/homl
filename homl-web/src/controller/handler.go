package controller

import "github.com/alkariin/homl/homl-web/model"

type Handler struct {
	CategoriesService model.CategoriesService
	EventsService     model.EventsService
	PersonsService    model.PersonsService
	SettingsService   model.SettingsService
	TagsService       model.TagsService
	UsersService      model.UsersService
}
