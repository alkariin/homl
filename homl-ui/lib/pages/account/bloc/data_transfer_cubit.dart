import 'dart:developer';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:homl/data/repositories/data_transfer.repository.dart';
import 'package:homl/data/transfer/export_file.dart';
import 'package:homl/data/transfer/export_seal.dart';
import 'package:homl/helpers/app_message.dart';

part 'data_transfer_state.dart';

/// What reading a picked file gave.
enum ReadResult {
  ok,

  /// A sealed file: ask for its password, then read again with it.
  passwordRequired,
  passwordWrong,

  /// Not readable (a toast already said why).
  failed,
}

/// Export and import of the account's data, behind the two rows of the
/// account page. The view drives the dialogs and the platform file pickers;
/// this cubit runs the work, reports the progress and turns the failures
/// into messages.
class DataTransferCubit extends Cubit<DataTransferState> {
  final DataTransferRepository repository;

  DataTransferCubit(this.repository) : super(const DataTransferState());

  /// The bytes of the export file, sealed with [password] when given; null
  /// when it failed (a toast says so).
  Future<Uint8List?> export({String? password}) async {
    if (state.busy) return null;
    emit(const DataTransferState(status: DataTransferStatus.exporting));
    try {
      final bytes = await repository.export(password: password);
      emit(const DataTransferState());
      return bytes;
    } catch (err) {
      log('Export failed', name: 'DataTransferCubit', error: err);
      emit(const DataTransferState(modal: AppMessage.exportFailed));
      return null;
    }
  }

  /// Reads a picked file; [ReadResult.ok] comes with the file.
  Future<(ReadResult, ExportFile?)> read(Uint8List bytes,
      {String? password}) async {
    if (state.busy) return (ReadResult.failed, null);
    emit(const DataTransferState(status: DataTransferStatus.reading));
    try {
      final file = await repository.read(bytes, password: password);
      emit(const DataTransferState());
      return (ReadResult.ok, file);
    } on ExportPasswordRequiredFailure {
      emit(const DataTransferState());
      return (ReadResult.passwordRequired, null);
    } on ExportPasswordFailure {
      emit(const DataTransferState());
      return (ReadResult.passwordWrong, null);
    } on ExportVersionFailure {
      emit(const DataTransferState(modal: AppMessage.importNewerVersion));
    } catch (err) {
      log('Unreadable import file', name: 'DataTransferCubit', error: err);
      emit(const DataTransferState(modal: AppMessage.importInvalidFile));
    }
    return (ReadResult.failed, null);
  }

  /// Imports [file]; the report when it ran to the end, null otherwise (a
  /// toast says why).
  Future<ImportReport?> import(ExportFile file) async {
    if (state.busy) return null;
    emit(const DataTransferState(status: DataTransferStatus.importing));
    try {
      final report = await repository.import(file,
          onProgress: (done, total) => emit(DataTransferState(
              status: DataTransferStatus.importing, done: done, total: total)));
      emit(const DataTransferState());
      return report;
    } on ImportUnavailableFailure catch (err) {
      emit(DataTransferState(
          modal: err.pendingChanges
              ? AppMessage.pendingChangesFirst
              : AppMessage.serverUnreachable));
    } on ImportInterruptedFailure {
      emit(const DataTransferState(modal: AppMessage.importInterrupted));
    } catch (err) {
      log('Import failed', name: 'DataTransferCubit', error: err);
      emit(DataTransferState(modal: AppMessage.requestFailed));
    }
    return null;
  }

  void endModal() {
    emit(DataTransferState(
        status: state.status, done: state.done, total: state.total));
  }
}
