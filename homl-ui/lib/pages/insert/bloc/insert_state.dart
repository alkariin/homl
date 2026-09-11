part of 'insert_cubit.dart';

enum InsertStatus { editing, submitting, success }

/// The three shapes an event can take. Derived from [InsertState.endDate] and
/// [InsertState.isOngoing], never stored: "a period without an end yet" is
/// not representable, so the form cannot rest in it and submit needs no
/// guard against it.
enum PeriodShape { singleDay, closed, ongoing }

class InsertState extends Equatable {
  final List<String> tagNames;

  /// Start of the event — its only day unless it is a period.
  final DateTime date;

  /// Inclusive last day of a closed period; null otherwise.
  final DateTime? endDate;

  /// Open period, no end yet. Never true together with an [endDate].
  final bool isOngoing;

  final String description;
  final InsertStatus status;
  final AppMessage? modal;

  /// Id of the event being edited; null when the form creates a new event.
  final int? editingEventId;

  const InsertState(
      {required this.tagNames,
      required this.date,
      this.endDate,
      this.isOngoing = false,
      required this.description,
      required this.status,
      this.modal,
      this.editingEventId});

  PeriodShape get shape => isOngoing
      ? PeriodShape.ongoing
      : endDate != null
          ? PeriodShape.closed
          : PeriodShape.singleDay;

  InsertState.initial()
      : this(
            tagNames: [],
            date: DateTime.now(),
            description: "",
            status: InsertStatus.editing);

  /// Prefills the form from an existing event. The date tags (categories in
  /// [dateCategoryIds]: months, years, Ongoing) are excluded: the backend
  /// rebuilds them from the period on every update, so resubmitting them
  /// would attach them as regular tags.
  InsertState.fromEvent(Event event, Set<int> dateCategoryIds)
      : this(
            tagNames: event.tags
                .where((tag) => !dateCategoryIds.contains(tag.idCategory))
                .map((tag) => tag.tag)
                .toList(),
            date: event.date,
            endDate: event.endDate,
            isOngoing: event.isOngoing,
            description: event.description,
            status: InsertStatus.editing,
            editingEventId: event.id);

  /// [clearEndDate] is the only way back to a null end date, as [clearModal]
  /// is for the modal: a null argument means "keep".
  InsertState copyWith(
      {List<String>? tagNames,
      DateTime? date,
      DateTime? endDate,
      bool clearEndDate = false,
      bool? isOngoing,
      String? description,
      InsertStatus? status,
      AppMessage? modal,
      bool clearModal = false}) {
    return InsertState(
      tagNames: tagNames ?? this.tagNames,
      date: date ?? this.date,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      isOngoing: isOngoing ?? this.isOngoing,
      description: description ?? this.description,
      status: status ?? this.status,
      modal: clearModal ? null : (modal ?? this.modal),
      editingEventId: editingEventId,
    );
  }

  @override
  List<Object?> get props => [
        tagNames,
        date,
        endDate,
        isOngoing,
        description,
        status,
        modal,
        editingEventId
      ];
}
