import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:homl/components/update_notice.dart';
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

  group('outdatedServerRelease', () {
    test('names the server release when it is older than the minimum', () {
      expect(
          outdatedServerRelease(server: 'v0.5.2', minimum: '0.6.0'), '0.5.2');
      expect(
          outdatedServerRelease(server: 'v0.9.0', minimum: '0.10.0'), '0.9.0');
      // A build past an older tag is still that older release.
      expect(
          outdatedServerRelease(server: 'v0.5.0-18-g9a09439', minimum: '0.6.0'),
          '0.5.0');
    });

    test('nothing when the server is the minimum or newer', () {
      expect(outdatedServerRelease(server: 'v0.6.0', minimum: '0.6.0'), isNull);
      expect(outdatedServerRelease(server: 'v0.6.2', minimum: '0.6.0'), isNull);
      expect(
          outdatedServerRelease(server: 'v0.10.0', minimum: '0.9.0'), isNull);
    });

    test('nothing when the server is not a release number', () {
      expect(
          outdatedServerRelease(server: '9a09439', minimum: '0.6.0'), isNull);
      expect(outdatedServerRelease(server: 'dev', minimum: '0.6.0'), isNull);
    });

    // The minimum is raised by hand: never past the app's own release, or
    // even a server as new as the app would be called too old.
    test('the minimum is not newer than this app', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version =
          RegExp(r'^version: *(\S+)', multiLine: true).firstMatch(pubspec)![1]!;
      expect(
          outdatedServerRelease(server: 'v$version', minimum: minServerRelease),
          isNull,
          reason: 'minServerRelease $minServerRelease is newer than the '
              'pubspec version $version');
    });
  });

  group('UpdateNoticeButton', () {
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

    // The app-update cases run against a minimum every server here meets,
    // whatever minServerRelease has become.
    Future<void> pumpButton(WidgetTester tester,
        {String minimum = '0.1.0'}) async {
      await tester.pumpWidget(RepositoryProvider<SettingsRepository>.value(
        value: repository,
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
              appBar: AppBar(actions: [UpdateNoticeButton(minimum: minimum)])),
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

    testWidgets(
        'never offers an app update off Android, which has no '
        'published build', (tester) async {
      when(() => repository.getServerVersion())
          .thenAnswer((_) async => 'v0.6.0');
      ServerReachability.instance.markOnline();
      await pumpButton(tester);

      expect(find.byTooltip('Update available'), findsNothing);
      expect(find.byTooltip('Server update needed'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('asks for a server update when the server is too old',
        (tester) async {
      when(() => repository.getServerVersion())
          .thenAnswer((_) async => 'v0.4.2');
      ServerReachability.instance.markOnline();
      await pumpButton(tester, minimum: '0.5.0');

      // Not an app update, though the app (0.5.0) is the newer one.
      expect(find.byTooltip('Update available'), findsNothing);
      await tester.tap(find.byTooltip('Server update needed'));
      await tester.pumpAndSettle();
      expect(find.text('Server update needed'), findsOneWidget);
      expect(
          find.text('The server runs 0.4.2, and this app needs 0.5.0 or '
              'newer: some features may fail until the server is upgraded.'),
          findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byTooltip('Server update needed'), findsOneWidget);
    }, variant: TargetPlatformVariant.all());

    // The app upgraded ahead of its server, which still does all it needs:
    // the common case, nothing to say.
    testWidgets('silent while the server is behind the app but not the minimum',
        (tester) async {
      when(() => repository.getServerVersion())
          .thenAnswer((_) async => 'v0.4.2');
      ServerReachability.instance.markOnline();
      await pumpButton(tester, minimum: '0.4.0');

      expect(find.byTooltip('Server update needed'), findsNothing);
      expect(find.byTooltip('Update available'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the server notice goes once the server is upgraded',
        (tester) async {
      when(() => repository.getServerVersion())
          .thenAnswer((_) async => 'v0.4.2');
      ServerReachability.instance.markOnline();
      await pumpButton(tester, minimum: '0.5.0');
      expect(find.byTooltip('Server update needed'), findsOneWidget);

      // Unreachable while it restarts: the notice stays meanwhile.
      when(() => repository.getServerVersion()).thenAnswer((_) async => null);
      ServerReachability.instance.markOffline();
      ServerReachability.instance.markOnline();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Server update needed'), findsOneWidget);

      when(() => repository.getServerVersion())
          .thenAnswer((_) async => 'v0.5.0');
      ServerReachability.instance.markOffline();
      ServerReachability.instance.markOnline();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Server update needed'), findsNothing);
      expect(find.byTooltip('Update available'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
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
