import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:homl/data/models/category.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart' show TagView;

part 'insert_state.dart';

class InsertCubit extends Cubit<InsertState> {
  final EventsRepository eventsRepository;
  final TagsRepository tagsRepository;

  InsertCubit(this.eventsRepository, this.tagsRepository)
      : super(InsertState.initial());

  /// Category used to create the tags typed freely in the input. When the
  /// backend exposes a category kind, the "other" category is used directly;
  /// otherwise we fall back to the legacy convention: the first category is
  /// Dates, then Persons, then Others — free tags land in Others (same bucket
  /// as a category deletion with moveTags).
  int? _defaultCategoryId(List<Category> categories) {
    if (categories.isEmpty) return null;

    for (var category in categories) {
      if (category.kind == CategoryKind.other) return category.id;
    }

    final idOthers = categories.first.id + 2;
    if (categories.any((c) => c.id == idOthers)) return idOthers;

    for (var category in categories) {
      if (!category.isLocked) return category.id;
    }
    return null;
  }

  /// Case-insensitive lookup in the known tags.
  TagView? _findExistingTag(Iterable<TagView> knownTags, String name) {
    for (var tagView in knownTags) {
      if (tagView.tagName.toLowerCase() == name.toLowerCase()) return tagView;
    }
    return null;
  }

  void addTag(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        state.tagNames.any((t) => t.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }

    emit(state.copyWith(tagNames: [...state.tagNames, trimmed]));
  }

  void removeTag(String name) {
    emit(state.copyWith(
        tagNames: state.tagNames.where((t) => t != name).toList()));
  }

  void updateDate(DateTime date) {
    emit(state.copyWith(date: date));
  }

  void updateDescription(String text) {
    emit(state.copyWith(description: text));
  }

  Future<void> submitEvent(
      List<Category> categories, Map<String, TagView> knownTags) async {
    if (state.status == InsertStatus.submitting) return;
    if (state.tagNames.isEmpty) {
      emit(state.copyWith(modal: AppMessage.insertNoTags));
      return;
    }

    emit(state.copyWith(status: InsertStatus.submitting));

    try {
      // Resolve the tag ids, creating the tags that do not exist yet
      final tagsId = <int>[];
      for (var name in state.tagNames) {
        final existing = _findExistingTag(knownTags.values, name);
        if (existing != null) {
          tagsId.add(existing.id);
          continue;
        }

        final idCategory = _defaultCategoryId(categories);
        if (idCategory == null) {
          throw EventsRequestFailure();
        }
        tagsId.add(await tagsRepository.createTag(name, idCategory));
      }

      // The repository notifies its change stream, which refreshes the
      // shared events/tags in the HomeCubit without coupling the cubits.
      await eventsRepository.createEvent(
          description: state.description,
          date: state.date,
          tagsId: tagsId);

      // Reset the form
      emit(InsertState.initial().copyWith(status: InsertStatus.success));
    } catch (_) {
      emit(state.copyWith(
          status: InsertStatus.editing, modal: AppMessage.unexpectedError));
    }
  }

  void endModal() {
    emit(state.copyWith(clearModal: true, status: InsertStatus.editing));
  }
}
