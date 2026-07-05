import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';

import 'package:homl/data/models/settings.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';

part 'home_event.dart';
part 'home_state.dart';

// Common bloc to share state between views
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final AppLocalizations localization;
  final EventsRepository eventsRepository;
  final CategoriesRepository categoriesRepository;
  final TagsRepository tagsRepository;
  final SettingsRepository settingsRepository;
  late StreamSubscription _settingsSubscription;

  HomeBloc(this.localization, this.settingsRepository, this.eventsRepository,
      this.categoriesRepository, this.tagsRepository, username)
      : super(HomeState.initial(username)) {
    on<UpdateSettings>(_onUpdateSettings);
    on<EndModal>(_onEndModal);
    on<ErrorModal>(_onErrorModal);
    on<Init>(_onInit);
    on<CreateTag>(_onCreateTag);
    on<UpdateTag>(_onUpdateTag);
    on<DeleteTag>(_onDeleteTag);

    _settingsSubscription =
        settingsRepository.settingsStream.listen((settings) {
      log('Settings received from stream', name: 'HomeBloc');
      add(UpdateSettings(settings));
    }, onError: (error) {
      log('Failed to retrieve settings stream event',
          name: 'HomeBloc', error: error);
      add(ErrorModal(localization.global_unexpectedError));
    });

    add(Init());
  }

  void _onCreateTag(CreateTag event, Emitter<HomeState> emit) {}

  void _onUpdateTag(UpdateTag event, Emitter<HomeState> emit) {}

  void _onDeleteTag(DeleteTag event, Emitter<HomeState> emit) {}

  Future<void> _onInit(Init event, Emitter<HomeState> emit) async {
    try {
      final events = await eventsRepository.getEvents();
      final categories = await categoriesRepository.getCategories();

      Map<String, TagView> tagMap = {};

      for (var category in categories) {
        for (var tag in category.tags) {
          tagMap[tag.tag] =
              TagView(tag.id, category.color, tag.tag, category.id);
        }
      }

      var sortedEntries = tagMap.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      Map<String, TagView> sortedTagsMap = Map.fromEntries(sortedEntries);

      emit(state.copyWith(
          events: events, categories: categories, allTagsMap: sortedTagsMap));
    } catch (_) {
      emit(state.copyWith(modal: localization.global_unexpectedError));
    }
  }

  void _onUpdateSettings(UpdateSettings event, Emitter<HomeState> emit) {
    emit(state.copyWith(settings: event.settings));
  }

  void _onErrorModal(ErrorModal event, Emitter<HomeState> emit) {
    emit(state.copyWith(modal: event.error));
  }

  void _onEndModal(EndModal event, Emitter<HomeState> emit) {
    emit(state.copyWith(modal: null));
  }

  @override
  Future<void> close() {
    log('Closing settings subscription', name: 'HomeBloc');
    _settingsSubscription.cancel();
    return super.close();
  }
}
