import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:homl/components/app_update.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/helpers/localizations.dart';
import 'package:homl/helpers/server_reachability.dart';
import 'package:homl/helpers/version.dart';
import 'package:homl/l10n/app_localizations.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  group('newerServerRelease', () {
    test('names the server release when it is newer than the app', () {
      expect(newerServerRelease(server: 'v0.6.0', app: '0.5.0'), '0.6.0');
      expect(newerServerRelease(server: 'v0.5.1', app: '0.5.0'), '0.5.1');
      expect(newerServerRelease(server: 'v1.0.0', app: '0.12.3'), '1.0.0');
    });

    test('compares numbers, not text', () {
      expect(newerServerRelease(server: 'v0.10.0', app: '0.9.0'), '0.10.0');
      expect(newerServerRelease(server: 'v0.9.0', app: '0.10.0'), isNull);
    });

    test('a build past a tag counts as that release', () {
      expect(newerServerRelease(server: 'v0.6.0-3-gabc1234', app: '0.5.0'),
          '0.6.0');
      expect(newerServerRelease(server: 'v0.5.0-18-g9a09439', app: '0.5.0'),
          isNull);
      expect(
          newerServerRelease(server: 'v0.6.0-dirty', app: '0.5.0+5'), '0.6.0');
    });

    test('nothing when the app is as new or newer', () {
      expect(newerServerRelease(server: 'v0.5.0', app: '0.5.0'), isNull);
      expect(newerServerRelease(server: 'v0.5.0', app: '0.6.0'), isNull);
    });

    test('nothing when either side is not a release number', () {
      // A server built from a checkout without tags reports the bare hash.
      expect(newerServerRelease(server: '9a09439', app: '0.5.0'), isNull);
      expect(newerServerRelease(server: 'dev', app: '0.5.0'), isNull);
      expect(newerServerRelease(server: 'v0.6.0', app: ''), isNull);
    });

    test('the release page is the GitHub release of the tag', () {
      expect(releasePageUrl('0.6.0'),
          'https://github.com/alkariin/homl/releases/tag/v0.6.0');
    });
  });

  group('AppUpdateButton', () {
    late MockSettingsRepository repository;

    setUp(() {
      PackageInfo.setMockInitialValues(
          appName: 'homl',
          packageName: 'dev.homl.app',
          version: '0.5.0',
          buildNumber: '5',
          buildSignature: '');
      repository = MockSettingsRepository();
      ServerReachability.instance.reset();
    });

    Future<void> pumpButton(WidgetTester tester) async {
      await tester.pumpWidget(RepositoryProvider<SettingsRepository>.value(
        value: repository,
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(appBar: AppBar(actions: const [AppUpdateButton()])),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('appears once the server answers with a newer release',
        (tester) async {
      when(() => repository.getServerVersion())
          .thenAnswer((_) async => 'v0.6.0');
      await pumpButton(tester);

      // Not asked while the server has not been reached yet.
      verifyNever(() => repository.getServerVersion());
      expect(find.byTooltip('Update available'), findsNothing);

      ServerReachability.instance.markOnline();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Update available'), findsOneWidget);

      await tester.tap(find.byTooltip('Update available'));
      await tester.pumpAndSettle();
      expect(find.text('homl 0.6.0 is out'), findsOneWidget);
      expect(find.textContaining('this app is still 0.5.0'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byTooltip('Update available'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('stays hidden when the app is up to date', (tester) async {
      when(() => repository.getServerVersion())
          .thenAnswer((_) async => 'v0.5.0-18-g9a09439');
      ServerReachability.instance.markOnline();
      await pumpButton(tester);

      verify(() => repository.getServerVersion()).called(1);
      expect(find.byTooltip('Update available'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('asks again when the server is back after an offline spell',
        (tester) async {
      when(() => repository.getServerVersion()).thenAnswer((_) async => null);
      ServerReachability.instance.markOnline();
      await pumpButton(tester);
      expect(find.byTooltip('Update available'), findsNothing);

      when(() => repository.getServerVersion())
          .thenAnswer((_) async => 'v0.6.0');
      ServerReachability.instance.markOffline();
      ServerReachability.instance.markOnline();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Update available'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('never asks off Android, which has no published build',
        (tester) async {
      when(() => repository.getServerVersion())
          .thenAnswer((_) async => 'v0.6.0');
      ServerReachability.instance.markOnline();
      await pumpButton(tester);

      verifyNever(() => repository.getServerVersion());
      expect(find.byTooltip('Update available'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('AppUpdateDialog', () {
    Future<void> pumpDialog(
        WidgetTester tester, Future<bool> Function(Uri) open) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AppUpdateDialog(
                    release: '0.6.0', installed: '0.5.0', open: open),
              ),
              child: const Text('show'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('show'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens the release page and closes', (tester) async {
      final opened = <Uri>[];
      await pumpDialog(tester, (url) async {
        opened.add(url);
        return true;
      });

      await tester.tap(find.text('Release page'));
      await tester.pumpAndSettle();
      expect(opened,
          [Uri.parse('https://github.com/alkariin/homl/releases/tag/v0.6.0')]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Could not open the release page.'), findsNothing);
    });

    testWidgets('says so when nothing can open it', (tester) async {
      await pumpDialog(tester, (_) async => throw Exception('no browser'));

      await tester.tap(find.text('Release page'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Could not open the release page.'), findsOneWidget);
    });
  });
}
