part of 'insert_cubit.dart';

enum InsertStatus { editing, submitting, success }

class InsertState extends Equatable {
  final List<String> tagNames;
  final DateTime date;
  final String description;
  final InsertStatus status;
  final AppMessage? modal;

  /// Id of the event being edited; null when the form creates a new event.
  final int? editingEventId;

  const InsertState(
      {required this.tagNames,
      required this.date,
      required this.description,
      required this.status,
      this.modal,
      this.editingEventId});

  InsertState.initial()
      : this(
            tagNames: [],
            date: DateTime.now(),
            description: "",
            status: InsertStatus.editing);

  /// Prefills the form from an existing event. The month/year date tags
  /// (categories in [dateCategoryIds]) are excluded: the backend rebuilds
  /// them from the date on every update, so resubmitting them would attach
  /// them as regular tags.
  InsertState.fromEvent(Event event, Set<int> dateCategoryIds)
      : this(
            tagNames: event.tags
                .where((tag) => !dateCategoryIds.contains(tag.idCategory))
                .map((tag) => tag.tag)
                .toList(),
            date: event.date,
            description: event.description,
            status: InsertStatus.editing,
            editingEventId: event.id);

  InsertState copyWith(
      {List<String>? tagNames,
      DateTime? date,
      String? description,
      InsertStatus? status,
      AppMessage? modal,
      bool clearModal = false}) {
    return InsertState(
      tagNames: tagNames ?? this.tagNames,
      date: date ?? this.date,
      description: description ?? this.description,
      status: status ?? this.status,
      modal: clearModal ? null : (modal ?? this.modal),
      editingEventId: editingEventId,
    );
  }

  @override
  List<Object?> get props =>
      [tagNames, date, description, status, modal, editingEventId];
}
