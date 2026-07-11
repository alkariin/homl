import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/helpers/app_message.dart';

part 'list_event.dart';
part 'list_state.dart';

class ListBloc extends Bloc<ListEvent, ListState> {
  final EventsRepository eventsRepository;

  ListBloc(this.eventsRepository)
      : super(ListState.initial()) {
    on<FetchEvents>(_onFetchEvents);
    on<AddFilterTag>(_onAddFilterTag);
    on<RemoveFilterTag>(_onRemoveFilterTag);
    on<EndListModal>(_onEndListModal);

    add(FetchEvents());
  }

  Future<void> _fetch(Emitter<ListState> emit, List<String> filters) async {
    emit(state.copyWith(filters: filters, loading: true));
    try {
      final events = await eventsRepository.getEvents(tags: filters);
      emit(state.copyWith(events: events, loading: false));
    } catch (_) {
      emit(state.copyWith(loading: false, modal: AppMessage.unexpectedError));
    }
  }

  Future<void> _onFetchEvents(
      FetchEvents event, Emitter<ListState> emit) async {
    await _fetch(emit, state.filters);
  }

  Future<void> _onAddFilterTag(
      AddFilterTag event, Emitter<ListState> emit) async {
    final name = event.name.trim();
    if (name.isEmpty ||
        state.filters.any((f) => f.toLowerCase() == name.toLowerCase())) {
      return;
    }

    await _fetch(emit, [...state.filters, name]);
  }

  Future<void> _onRemoveFilterTag(
      RemoveFilterTag event, Emitter<ListState> emit) async {
    // Normalized the same way as the addition, so a tag added
    // case-insensitively can always be removed.
    final name = event.name.trim().toLowerCase();
    await _fetch(
        emit, state.filters.where((f) => f.toLowerCase() != name).toList());
  }

  void _onEndListModal(EndListModal event, Emitter<ListState> emit) {
    emit(state.copyWith(clearModal: true));
  }
}
