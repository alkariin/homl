import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/data/repositories/data_transfer.repository.dart';
import 'package:homl/data/transfer/export_file.dart';
import 'package:homl/data/transfer/export_seal.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/server_reachability.dart';
import 'package:homl/pages/account/bloc/data_transfer_cubit.dart';

class MockDataTransferRepository extends Mock
    implements DataTransferRepository {}

final _bytes = Uint8List.fromList([1, 2, 3]);
final _file = ExportFile(
    exportedAt: DateTime.utc(2026, 10, 17),
    categories: const [],
    events: const []);

void main() {
  late MockDataTransferRepository repository;

  setUpAll(() {
    registerFallbackValue(_file);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    ServerReachability.instance.reset();
    repository = MockDataTransferRepository();
  });

  group('read', () {
    Future<(ReadResult, ExportFile?)> readWith(Object failure) {
      when(() => repository.read(any(), password: any(named: 'password')))
          .thenThrow(failure);
      return DataTransferCubit(repository).read(_bytes);
    }

    test('hands over a valid file', () async {
      when(() => repository.read(any(), password: any(named: 'password')))
          .thenAnswer((_) async => _file);
      final (result, file) = await DataTransferCubit(repository).read(_bytes);
      expect(result, ReadResult.ok);
      expect(file, same(_file));
    });

    test('asks for the password of a sealed file', () async {
      expect((await readWith(ExportPasswordRequiredFailure())).$1,
          ReadResult.passwordRequired);
      expect((await readWith(ExportPasswordFailure())).$1,
          ReadResult.passwordWrong);
    });

    blocTest<DataTransferCubit, DataTransferState>(
      'says a file from a newer app apart from a broken one',
      build: () => DataTransferCubit(repository),
      setUp: () =>
          when(() => repository.read(any(), password: any(named: 'password')))
              .thenThrow(ExportVersionFailure()),
      act: (cubit) => cubit.read(_bytes),
      expect: () => [
        const DataTransferState(status: DataTransferStatus.reading),
        const DataTransferState(modal: AppMessage.importNewerVersion),
      ],
    );

    blocTest<DataTransferCubit, DataTransferState>(
      'a broken file is reported as such',
      build: () => DataTransferCubit(repository),
      setUp: () =>
          when(() => repository.read(any(), password: any(named: 'password')))
              .thenThrow(const ExportFormatFailure('nope')),
      act: (cubit) => cubit.read(_bytes),
      expect: () => [
        const DataTransferState(status: DataTransferStatus.reading),
        const DataTransferState(modal: AppMessage.importInvalidFile),
      ],
    );
  });

  group('import', () {
    blocTest<DataTransferCubit, DataTransferState>(
      'shows the progress, then hands over the report',
      build: () => DataTransferCubit(repository),
      setUp: () => when(() =>
              repository.import(any(), onProgress: any(named: 'onProgress')))
          .thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(int, int);
        onProgress(0, 2);
        onProgress(1, 2);
        onProgress(2, 2);
        return ImportReport()..eventsCreated = 2;
      }),
      act: (cubit) async {
        final report = await cubit.import(_file);
        expect(report?.eventsCreated, 2);
      },
      expect: () => [
        const DataTransferState(status: DataTransferStatus.importing),
        const DataTransferState(
            status: DataTransferStatus.importing, done: 0, total: 2),
        const DataTransferState(
            status: DataTransferStatus.importing, done: 1, total: 2),
        const DataTransferState(
            status: DataTransferStatus.importing, done: 2, total: 2),
        const DataTransferState(),
      ],
    );

    final failures = <String, (Exception, AppMessage)>{
      'offline': (
        const ImportUnavailableFailure(pendingChanges: false),
        AppMessage.serverUnreachable
      ),
      'with offline changes waiting': (
        const ImportUnavailableFailure(pendingChanges: true),
        AppMessage.pendingChangesFirst
      ),
      'cut short': (
        ImportInterruptedFailure(ImportReport()),
        AppMessage.importInterrupted
      ),
    };
    for (final entry in failures.entries) {
      blocTest<DataTransferCubit, DataTransferState>(
        'says why an import ${entry.key} stopped',
        build: () => DataTransferCubit(repository),
        setUp: () => when(() =>
                repository.import(any(), onProgress: any(named: 'onProgress')))
            .thenThrow(entry.value.$1),
        act: (cubit) async => expect(await cubit.import(_file), isNull),
        expect: () => [
          const DataTransferState(status: DataTransferStatus.importing),
          DataTransferState(modal: entry.value.$2),
        ],
      );
    }
  });

  blocTest<DataTransferCubit, DataTransferState>(
    'a failed export says so',
    build: () => DataTransferCubit(repository),
    setUp: () => when(() => repository.export(password: any(named: 'password')))
        .thenThrow(Exception('boom')),
    act: (cubit) async => expect(await cubit.export(), isNull),
    expect: () => [
      const DataTransferState(status: DataTransferStatus.exporting),
      const DataTransferState(modal: AppMessage.exportFailed),
    ],
  );
}
