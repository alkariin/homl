import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';

import 'package:homl/data/models/settings.dart';
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

  Future<void> refreshEvents() async {
    try {
      final events = await eventsRepository.getEvents();
      emit(state.copyWith(events: events));
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
    }
  }

  Future<void> createTag(String text, int idCategory, {int? idParentTag}) async {
    try {
      await tagsRepository.createTag(text, idCategory,
          idParentTag: idParentTag);
      await _refreshCategories();
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
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

  Future<void> deleteTag(int id) async {
    try {
      await tagsRepository.deleteTag(id);
      await _refreshCategories();
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.unexpectedError));
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

  Future<void> deleteCategory(int id, {bool moveTags = false}) async {
    try {
      await categoriesRepository.deleteCategory(id, moveTags: moveTags);
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
