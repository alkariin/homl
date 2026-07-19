import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';

import 'package:homl/data/models/settings.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/models/usage.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/helpers/app_message.dart';

part 'home_state.dart';

// Common cubit to share state between views
class HomeCubit extends Cubit<HomeState> {
  final EventsRepository eventsRepository;
  final CategoriesRepository categoriesRepository;
  final TagsRepository tagsRepository;
  final SettingsRepository settingsRepository;
  late StreamSubscription<Settings> _settingsSubscription;
  late StreamSubscription<void> _eventsChangedSubscription;

  HomeCubit(this.settingsRepository, this.eventsRepository,
      this.categoriesRepository, this.tagsRepository, String username)
      : super(HomeState.initial(username)) {
    _settingsSubscription =
        settingsRepository.settingsStream.listen((settings) {
      log('Settings received from stream', name: 'HomeCubit');
      emit(state.copyWith(settings: settings));
    }, onError: (error) {
      log('Failed to retrieve settings stream event',
          name: 'HomeCubit', error: error);
      errorModal(AppMessage.unexpectedError);
    });

    // Refresh the shared events/categories when another page (e.g. the
    // insert form) reports a change through the repository stream.
    _eventsChangedSubscription = eventsRepository.changes.listen((_) {
      init();
    });

    init();
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
  Future<void> _refreshCategories() async {
    final categories = await categoriesRepository.getCategories();
    emit(state.copyWith(
        categories: categories, allTagsMap: _buildTagsMap(categories)));
  }

  Future<void> init() async {
    // Serve the cached snapshot first: the UI is usable immediately (and
    // offline); the network refresh below overwrites it when it lands.
    if (!state.initialized) {
      final cachedEvents = await eventsRepository.getCachedEvents();
      final cachedCategories = await categoriesRepository.getCachedCategories();

      if (cachedEvents != null && cachedCategories != null) {
        emit(state.copyWith(
            events: cachedEvents,
            categories: cachedCategories,
            allTagsMap: _buildTagsMap(cachedCategories),
            initialized: true));
      }
    }

    try {
      final events = await eventsRepository.getEvents();
      final categories = await categoriesRepository.getCategories();

      emit(state.copyWith(
          events: events,
          categories: categories,
          allTagsMap: _buildTagsMap(categories),
          initialized: true));
    } catch (_) {
      // Offline with a cached snapshot on screen: stale data is fine.
      if (!state.initialized) {
        emit(state.copyWith(modal: AppMessage.unexpectedError));
      }
    }
  }

  Future<void> refreshEvents() async {
    try {
      final events = await eventsRepository.getEvents();
      emit(state.copyWith(events: events));
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  Future<void> deleteEvent(int id) async {
    try {
      // The repository change stream triggers init(), which refreshes the
      // shared events (and rewrites the offline cache).
      await eventsRepository.deleteEvent(id);
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  /// Returns true when the tag was created (false emits an error modal), so
  /// callers chaining on the creation (e.g. the insert page tagging its
  /// event with the new tag) know whether to proceed.
  Future<bool> createTag(String text, int idCategory,
      {int? idParentTag}) async {
    try {
      await tagsRepository.createTag(text, idCategory,
          idParentTag: idParentTag);
      await _refreshCategories();
      return true;
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
      return false;
    }
  }

  Future<void> updateTag(int id, String text, int idCategory,
      {int? idParentTag}) async {
    try {
      await tagsRepository.updateTag(id, text, idCategory,
          idParentTag: idParentTag);
      await _refreshCategories();
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  /// [deleteEvents] only matters for main tags: it also deletes the events
  /// whose only non-date tags belonged to the deleted synonym group.
  Future<void> deleteTag(int id, {bool deleteEvents = false}) async {
    try {
      await tagsRepository.deleteTag(id, deleteEvents: deleteEvents);
      // The events changed too: deleted, or stripped of the removed tags.
      await refreshEvents();
      await _refreshCategories();
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  /// Moves a main tag (with its synonyms, handled by the backend) to another
  /// category, keeping its name and synonym links.
  Future<void> moveTag(Tag tag, int idCategory) async {
    try {
      await tagsRepository.updateTag(tag.id, tag.tag, idCategory,
          idParentTag: tag.idParentTag);
      // Event payloads embed the tag's category: refresh them too.
      await refreshEvents();
      await _refreshCategories();
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  /// Event counts for the tag's synonym group, or null when the request
  /// fails (an error modal is emitted instead).
  Future<TagUsage?> fetchTagUsage(int id) async {
    try {
      return await tagsRepository.getTagUsage(id);
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
      return null;
    }
  }

  /// Tag/event counts for a category, or null when the request fails (an
  /// error modal is emitted instead).
  Future<CategoryUsage?> fetchCategoryUsage(int id) async {
    try {
      return await categoriesRepository.getCategoryUsage(id);
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
      return null;
    }
  }

  Future<void> createCategory(String name, String color) async {
    try {
      await categoriesRepository.createCategory(name, color);
      await _refreshCategories();
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  Future<void> updateCategory(int id, String name, String color) async {
    try {
      await categoriesRepository.updateCategory(id, name, color);
      await _refreshCategories();
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  /// [moveTags] moves the tags to the Other category; otherwise the tags are
  /// deleted and [deleteEvents] also deletes the events whose only non-date
  /// tags lived in this category.
  Future<void> deleteCategory(int id,
      {bool moveTags = false, bool deleteEvents = false}) async {
    try {
      await categoriesRepository.deleteCategory(id,
          moveTags: moveTags, deleteEvents: deleteEvents);
      // The events changed too: deleted, or stripped of the removed tags.
      await refreshEvents();
      await _refreshCategories();
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  void errorModal(AppMessage error) {
    emit(state.copyWith(modal: error));
  }

  void endModal() {
    emit(state.copyWith(clearModal: true));
  }

  @override
  Future<void> close() {
    log('Closing settings subscription', name: 'HomeCubit');
    _settingsSubscription.cancel();
    _eventsChangedSubscription.cancel();
    return super.close();
  }
}
