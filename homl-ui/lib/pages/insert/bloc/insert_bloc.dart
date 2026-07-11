import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:homl/data/models/category.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/pages/home/bloc/home_bloc.dart' show TagView;

part 'insert_event.dart';
part 'insert_state.dart';

class InsertBloc extends Bloc<InsertEvent, InsertState> {
  final EventsRepository eventsRepository;
  final TagsRepository tagsRepository;

  InsertBloc(this.eventsRepository, this.tagsRepository)
      : super(InsertState.initial()) {
    on<AddTag>(_onAddTag);
    on<RemoveTag>(_onRemoveTag);
    on<UpdateDate>(_onUpdateDate);
    on<UpdateDescription>(_onUpdateDescription);
    on<SubmitEvent>(_onSubmitEvent);
    on<EndInsertModal>(_onEndInsertModal);
  }

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

  void _onAddTag(AddTag event, Emitter<InsertState> emit) {
    final name = event.name.trim();
    if (name.isEmpty ||
        state.tagNames.any((t) => t.toLowerCase() == name.toLowerCase())) {
      return;
    }

    emit(state.copyWith(tagNames: [...state.tagNames, name]));
  }

  void _onRemoveTag(RemoveTag event, Emitter<InsertState> emit) {
    emit(state.copyWith(
        tagNames: state.tagNames.where((t) => t != event.name).toList()));
  }

  void _onUpdateDate(UpdateDate event, Emitter<InsertState> emit) {
    emit(state.copyWith(date: event.date));
  }

  void _onUpdateDescription(UpdateDescription event, Emitter<InsertState> emit) {
    emit(state.copyWith(description: event.text));
  }

  Future<void> _onSubmitEvent(
      SubmitEvent event, Emitter<InsertState> emit) async {
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
        final existing = _findExistingTag(event.knownTags.values, name);
        if (existing != null) {
          tagsId.add(existing.id);
          continue;
        }

        final idCategory = _defaultCategoryId(event.categories);
        if (idCategory == null) {
          throw EventsRequestFailure();
        }
        tagsId.add(await tagsRepository.createTag(name, idCategory));
      }

      // The repository notifies its change stream, which refreshes the
      // shared events/tags in the HomeBloc without coupling the blocs.
      await eventsRepository.createEvent(
          description: state.description,
          date: state.date,
          tagsId: tagsId);

      // Reset the form
      emit(InsertState.initial().copyWith(status: InsertStatus.success));
    } catch (_) {
      emit(state.copyWith(
          status: InsertStatus.editing,
          modal: AppMessage.unexpectedError));
    }
  }

  void _onEndInsertModal(EndInsertModal event, Emitter<InsertState> emit) {
    emit(state.copyWith(clearModal: true, status: InsertStatus.editing));
  }
}
