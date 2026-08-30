import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:homl/data/models/settings.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/pages/settings/bloc/settings_cubit.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSettingsRepository repository;

  setUp(() {
    PackageInfo.setMockInitialValues(
        appName: 'homl',
        packageName: 'ch.homl.dev',
        version: '0.1.0',
        buildNumber: '1',
        buildSignature: '');
    repository = MockSettingsRepository();
    when(() => repository.settingsStream)
        .thenAnswer((_) => const Stream<Settings>.empty());
  });

  blocTest<SettingsCubit, SettingsState>(
    'shows the app build and the server version from /healthz',
    setUp: () => when(() => repository.getServerVersion())
        .thenAnswer((_) async => 'v0.1.0'),
    build: () => SettingsCubit(repository),
    expect: () => [
      const SettingsState(
          isFormSubmitted: false,
          appVersion: '0.1.0+1',
          serverVersion: 'v0.1.0',
          versionsLoaded: true),
    ],
  );

  blocTest<SettingsCubit, SettingsState>(
    'marks the versions loaded even when the server does not answer',
    setUp: () =>
        when(() => repository.getServerVersion()).thenAnswer((_) async => null),
    build: () => SettingsCubit(repository),
    expect: () => [
      const SettingsState(
          isFormSubmitted: false, appVersion: '0.1.0+1', versionsLoaded: true),
    ],
  );
}
