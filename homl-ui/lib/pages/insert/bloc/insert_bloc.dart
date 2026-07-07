import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/pages/home/bloc/home_bloc.dart';

part 'insert_event.dart';
part 'insert_state.dart';

class InsertBloc extends Bloc<InsertEvent, InsertState> {
  final AppLocalizations localization;
  final EventsRepository eventsRepository;
  final TagsRepository tagsRepository;
  final HomeBloc homeBloc;

  InsertBloc(this.localization, this.eventsRepository, this.tagsRepository,
      this.homeBloc)
      : super(InsertState.initial()) {
    on<AddTag>(_onAddTag);
    on<RemoveTag>(_onRemoveTag);
    on<UpdateDate>(_onUpdateDate);
    on<UpdateDescription>(_onUpdateDescription);
    on<SubmitEvent>(_onSubmitEvent);
    on<EndInsertModal>(_onEndInsertModal);
  }

  /// Category used to create the tags typed freely in the input. Backend
  /// convention: the first category is Dates, then Persons, then Others —
  /// free tags land in Others (same bucket as a category deletion with
  /// moveTags).
  int? _defaultCategoryId() {
    final categories = homeBloc.state.categories;
    if (categories.isEmpty) return null;

    final idOthers = categories.first.id + 2;
    if (categories.any((c) => c.id == idOthers)) return idOthers;

    for (var category in categories) {
      if (!category.isLocked) return category.id;
    }
    return null;
  }

  /// Case-insensitive lookup in the known tags.
  TagView? _findExistingTag(String name) {
    for (var tagView in homeBloc.state.allTagsMap.values) {
      if (tagView.tagName.toLowerCase() == name.toLowerCase()) return tagView;
    }
    return null;
  }

  _onAddTag(AddTag event, Emitter<InsertState> emit) {
    final name = event.name.trim();
    if (name.isEmpty ||
        state.tagNames.any((t) => t.toLowerCase() == name.toLowerCase())) {
      return;
    }

    emit(state.copyWith(tagNames: [...state.tagNames, name]));
  }

  _onRemoveTag(RemoveTag event, Emitter<InsertState> emit) {
    emit(state.copyWith(
        tagNames: state.tagNames.where((t) => t != event.name).toList()));
  }

  _onUpdateDate(UpdateDate event, Emitter<InsertState> emit) {
    emit(state.copyWith(date: event.date));
  }

  _onUpdateDescription(UpdateDescription event, Emitter<InsertState> emit) {
    emit(state.copyWith(description: event.text));
  }

  _onSubmitEvent(SubmitEvent event, Emitter<InsertState> emit) async {
    if (state.status == InsertStatus.submitting) return;
    if (state.tagNames.isEmpty) {
      emit(state.copyWith(modal: localization.insert_noTagsError));
      return;
    }

    emit(state.copyWith(status: InsertStatus.submitting));

    try {
      // Resolve the tag ids, creating the tags that do not exist yet
      final tagsId = <int>[];
      for (var name in state.tagNames) {
        final existing = _findExistingTag(name);
        if (existing != null) {
          tagsId.add(existing.id);
          continue;
        }

        final idCategory = _defaultCategoryId();
        if (idCategory == null) {
          throw Exception();
        }
        tagsId.add(await tagsRepository.createTag(name, idCategory));
      }

      await eventsRepository.createEvent(
          description: state.description,
          date: state.date,
          tagsId: tagsId);

      // Reset the form and refresh the shared events/tags
      emit(InsertState.initial().copyWith(status: InsertStatus.success));
      homeBloc.add(Init());
    } catch (_) {
      emit(state.copyWith(
          status: InsertStatus.editing,
          modal: localization.global_unexpectedError));
    }
  }

  _onEndInsertModal(EndInsertModal event, Emitter<InsertState> emit) {
    emit(state.copyWith(clearModal: true, status: InsertStatus.editing));
  }
}
