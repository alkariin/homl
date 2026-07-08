part of 'insert_bloc.dart';

enum InsertStatus { editing, submitting, success }

class InsertState extends Equatable {
  final List<String> tagNames;
  final DateTime date;
  final String description;
  final InsertStatus status;
  final AppMessage? modal;

  const InsertState(
      {required this.tagNames,
      required this.date,
      required this.description,
      required this.status,
      this.modal});

  InsertState.initial()
      : this(
            tagNames: [],
            date: DateTime.now(),
            description: "",
            status: InsertStatus.editing);

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
    );
  }

  @override
  List<Object?> get props => [tagNames, date, description, status, modal];
}
