import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/data/models/tag.dart';
import 'package:homl/data/repositories/tags.repository.dart';

part 'list_event.dart';
part 'list_state.dart';

class ListBloc extends Bloc<ListEvent, ListState> {
  final AppLocalizations localization;
  final TagsRepository tagsRepository;

  ListBloc(this.localization, this.tagsRepository)
      : super(ListState.initial()) {
    on<AddTagToHeader>(_onAddTagToHeader);
    on<RemoveTagFromHeader>(_onRemoveTagFromHeader);
  }

  Future<void> _onAddTagToHeader(AddTagToHeader event, Emitter<ListState> emit) async {
    try {
      Tag res = await tagsRepository.createTag(event.text, event.idCategory);
      var tags = state.tags.toList();
      tags.add(res);
      emit(state.copyWith(tags: tags));
    } catch (_) {
      emit(state.copyWith(modal: localization.global_unexpectedError));
    }
  }

  Future<void> _onRemoveTagFromHeader(
      RemoveTagFromHeader event, Emitter<ListState> emit) async {
    try {
      await tagsRepository.deleteTag(event.id);
      var tags = state.tags.toList();
      tags.removeWhere((tag) => tag.id == event.id);
      emit(state.copyWith(tags: tags));
    } catch (_) {
      emit(state.copyWith(modal: localization.global_unexpectedError));
    }
  }
}
