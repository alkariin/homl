import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';

import 'package:homl/data/models/settings.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/helpers/app_message.dart';

part 'home_event.dart';
part 'home_state.dart';

// Common bloc to share state between views
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final EventsRepository eventsRepository;
  final CategoriesRepository categoriesRepository;
  final TagsRepository tagsRepository;
  final SettingsRepository settingsRepository;
  late StreamSubscription<Settings> _settingsSubscription;
  late StreamSubscription<void> _eventsChangedSubscription;

  HomeBloc(this.settingsRepository, this.eventsRepository,
      this.categoriesRepository, this.tagsRepository, String username)
      : super(HomeState.initial(username)) {
    on<UpdateSettings>(_onUpdateSettings);
    on<EndModal>(_onEndModal);
    on<ErrorModal>(_onErrorModal);
    on<Init>(_onInit);
    on<RefreshEvents>(_onRefreshEvents);
    on<CreateTag>(_onCreateTag);
    on<UpdateTag>(_onUpdateTag);
    on<DeleteTag>(_onDeleteTag);
    on<CreateCategory>(_onCreateCategory);
    on<UpdateCategory>(_onUpdateCategory);
    on<DeleteCategory>(_onDeleteCategory);

    _settingsSubscription =
        settingsRepository.settingsStream.listen((settings) {
      log('Settings received from stream', name: 'HomeBloc');
      add(UpdateSettings(settings));
    }, onError: (error) {
      log('Failed to retrieve settings stream event',
          name: 'HomeBloc', error: error);
      add(const ErrorModal(AppMessage.unexpectedError));
    });

    // Refresh the shared events/categories when another page (e.g. the
    // insert form) reports a change through the repository stream.
    _eventsChangedSubscription = eventsRepository.changes.listen((_) {
      add(Init());
    });

    add(Init());
  }

  Map<String, TagView> _buildTagsMap(List<Category> categories) {
    Map<String, TagView> tagMap = {};

    for (var category in categories) {
      for (var tag in category.tags) {
        tagMap[tag.tag] = TagView(
            tag.id, category.color, tag.tag, category.id, tag.idParentTag);
      }
    }

    var sortedEntries = tagMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Map.fromEntries(sortedEntries);
  }

  /// Re-fetches the categories (and the tags map) after any tag/category CRUD.
  Future<void> _refreshCategories(Emitter<HomeState> emit) async {
    final categories = await categoriesRepository.getCategories();
    emit(state.copyWith(
        categories: categories, allTagsMap: _buildTagsMap(categories)));
  }

  Future<void> _onInit(Init event, Emitter<HomeState> emit) async {
    try {
      final events = await eventsRepository.getEvents();
      final categories = await categoriesRepository.getCategories();

      emit(state.copyWith(
          events: events,
          categories: categories,
          allTagsMap: _buildTagsMap(categories)));
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  Future<void> _onRefreshEvents(
      RefreshEvents event, Emitter<HomeState> emit) async {
    try {
      final events = await eventsRepository.getEvents();
      emit(state.copyWith(events: events));
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  Future<void> _onCreateTag(CreateTag event, Emitter<HomeState> emit) async {
    try {
      await tagsRepository.createTag(event.text, event.idCategory,
          idParentTag: event.idParentTag);
      await _refreshCategories(emit);
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  Future<void> _onUpdateTag(UpdateTag event, Emitter<HomeState> emit) async {
    try {
      await tagsRepository.updateTag(event.id, event.text, event.idCategory,
          idParentTag: event.idParentTag);
      await _refreshCategories(emit);
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  Future<void> _onDeleteTag(DeleteTag event, Emitter<HomeState> emit) async {
    try {
      await tagsRepository.deleteTag(event.id);
      await _refreshCategories(emit);
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  Future<void> _onCreateCategory(
      CreateCategory event, Emitter<HomeState> emit) async {
    try {
      await categoriesRepository.createCategory(event.name, event.color);
      await _refreshCategories(emit);
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  Future<void> _onUpdateCategory(
      UpdateCategory event, Emitter<HomeState> emit) async {
    try {
      await categoriesRepository.updateCategory(
          event.id, event.name, event.color);
      await _refreshCategories(emit);
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  Future<void> _onDeleteCategory(
      DeleteCategory event, Emitter<HomeState> emit) async {
    try {
      await categoriesRepository.deleteCategory(event.id,
          moveTags: event.moveTags);
      await _refreshCategories(emit);
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  void _onUpdateSettings(UpdateSettings event, Emitter<HomeState> emit) {
    emit(state.copyWith(settings: event.settings));
  }

  void _onErrorModal(ErrorModal event, Emitter<HomeState> emit) {
    emit(state.copyWith(modal: event.error));
  }

  void _onEndModal(EndModal event, Emitter<HomeState> emit) {
    emit(state.copyWith(clearModal: true));
  }

  @override
  Future<void> close() {
    log('Closing settings subscription', name: 'HomeBloc');
    _settingsSubscription.cancel();
    _eventsChangedSubscription.cancel();
    return super.close();
  }
}
