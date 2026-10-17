part of 'data_transfer_cubit.dart';

enum DataTransferStatus { idle, exporting, reading, importing }

class DataTransferState extends Equatable {
  final DataTransferStatus status;

  /// Progress of an import: items handled out of [total] (tags and events).
  final int done;
  final int total;

  final AppMessage? modal;

  const DataTransferState(
      {this.status = DataTransferStatus.idle,
      this.done = 0,
      this.total = 0,
      this.modal});

  bool get busy => status != DataTransferStatus.idle;

  @override
  List<Object?> get props => [status, done, total, modal];
}
