import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/helpers/app_message.dart';

part 'list_state.dart';

class ListCubit extends Cubit<ListState> {
  final EventsRepository eventsRepository;

  ListCubit(this.eventsRepository) : super(ListState.initial()) {
    fetchEvents();
  }

  Future<void> _fetch(List<String> filters) async {
    emit(state.copyWith(filters: filters, loading: true));
    try {
      final events = await eventsRepository.getEvents(tags: filters);
      emit(state.copyWith(events: events, loading: false));
    } catch (_) {
      emit(state.copyWith(loading: false, modal: AppMessage.unexpectedError));
    }
  }

  Future<void> fetchEvents() async {
    await _fetch(state.filters);
  }

  Future<void> addFilterTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        state.filters.any((f) => f.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }

    await _fetch([...state.filters, trimmed]);
  }

  Future<void> removeFilterTag(String name) async {
    // Normalized the same way as the addition, so a tag added
    // case-insensitively can always be removed.
    final trimmed = name.trim().toLowerCase();
    await _fetch(
        state.filters.where((f) => f.toLowerCase() != trimmed).toList());
  }

  void endModal() {
    emit(state.copyWith(clearModal: true));
  }
}
