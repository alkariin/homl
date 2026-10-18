import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/data/models/device_session.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/localizations.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/account/bloc/sessions_cubit.dart';
import 'package:homl/pages/account/view/sessions.dart';

class MockUsersRepository extends Mock implements UsersRepository {}

/// Answers /sessions like the server, recording what it was asked.
class _Server implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  int deleteStatus = 204;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (options.method == 'GET') {
      return ResponseBody.fromString(
          jsonEncode([
            {
              'id': 'laptop',
              'client': 'web 0.5.0',
              'ip': '192.0.2.7',
              'createdAt': '2026-10-12T08:00:00Z',
              'lastSeenAt': '2026-10-18T09:52:00Z',
              'current': true,
            },
            {
              'id': 'old',
              'client': '',
              'ip': '',
              'createdAt': null,
              'lastSeenAt': '2026-10-01T10:00:00Z',
              'current': false,
            },
          ]),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          });
    }
    return ResponseBody.fromString('', deleteStatus);
  }

  @override
  void close({bool force = false}) {}
}

DeviceSession session(String id,
        {String client = 'android 0.5.0',
        bool current = false,
        DateTime? createdAt}) =>
    DeviceSession(
        id: id,
        client: client,
        ip: '10.0.0.2',
        createdAt: createdAt,
        lastSeenAt: DateTime(2026, 10, 18, 9, 52),
        current: current);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the repository', () {
    late _Server server;
    late UsersRepository repository;

    setUp(() {
      server = _Server();
      final api = Api.internal(
          baseUrlOverride: 'https://api.test', initFromStorage: false);
      api.api.httpClientAdapter = server;
      repository = UsersRepository(api: api);
    });

    test('lists the devices, this one first', () async {
      final sessions = await repository.listSessions();

      expect(sessions.map((s) => s.id), ['laptop', 'old']);
      expect(sessions.first.current, isTrue);
      expect(sessions.first.platform, 'web');
      expect(sessions.first.version, '0.5.0');
      expect(sessions.last.createdAt, isNull);
      expect(sessions.last.version, isNull);
    });

    test('every request says what the app is', () async {
      await repository.listSessions();

      // The tests run as Android, the package info is out of reach.
      expect(server.requests.single.headers['X-Homl-Client'], 'android');
    });

    test('signing out a device gone already is done', () async {
      server.deleteStatus = 404;
      await repository.revokeSession('gone');
      expect(server.requests.single.path, endsWith('/sessions/gone'));

      server.deleteStatus = 500;
      await expectLater(repository.revokeOtherSessions(),
          throwsA(isA<SessionsRequestFailure>()));
    });
  });

  group('the cubit', () {
    late MockUsersRepository users;
    setUp(() => users = MockUsersRepository());

    blocTest<SessionsCubit, SessionsState>(
      'loads the list',
      build: () {
        when(() => users.listSessions())
            .thenAnswer((_) async => [session('phone', current: true)]);
        return SessionsCubit(users);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        predicate<SessionsState>((s) => s.status == SessionsStatus.loading),
        predicate<SessionsState>(
            (s) => s.status == SessionsStatus.loaded && s.sessions.length == 1),
      ],
    );

    blocTest<SessionsCubit, SessionsState>(
      'says when the list cannot be read',
      build: () {
        when(() => users.listSessions()).thenThrow(SessionsRequestFailure());
        return SessionsCubit(users);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        predicate<SessionsState>((s) => s.status == SessionsStatus.loading),
        predicate<SessionsState>((s) => s.status == SessionsStatus.failed),
      ],
    );

    blocTest<SessionsCubit, SessionsState>(
      'signs a device out, then reads the list again',
      build: () {
        when(() => users.revokeSession('tablet')).thenAnswer((_) async {});
        when(() => users.listSessions())
            .thenAnswer((_) async => [session('phone', current: true)]);
        return SessionsCubit(users);
      },
      act: (cubit) => cubit.signOut('tablet'),
      verify: (_) {
        verify(() => users.revokeSession('tablet')).called(1);
        verify(() => users.listSessions()).called(1);
      },
    );

    blocTest<SessionsCubit, SessionsState>(
      'a failed sign-out is said once and changes nothing',
      build: () {
        when(() => users.revokeOtherSessions())
            .thenThrow(SessionsRequestFailure());
        return SessionsCubit(users);
      },
      seed: () => SessionsState(
          status: SessionsStatus.loaded,
          sessions: [session('phone', current: true), session('tablet')]),
      act: (cubit) => cubit.signOutOthers(),
      expect: () => [
        predicate<SessionsState>((s) => s.busy),
        predicate<SessionsState>(
            (s) => !s.busy && s.actionFailed && s.sessions.length == 2),
      ],
    );
  });

  group('the page', () {
    late MockUsersRepository users;
    setUp(() => users = MockUsersRepository());

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(RepositoryProvider<UsersRepository>.value(
        value: users,
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    Navigator.of(context).push(SessionsPage.route(context)),
                child: const Text('security page'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('security page'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists this device first, the others with a sign-out',
        (tester) async {
      when(() => users.listSessions()).thenAnswer((_) async => [
            session('phone',
                current: true, createdAt: DateTime(2026, 10, 12, 8)),
            session('laptop', client: 'web 0.5.0'),
            session('old', client: ''),
          ]);

      await open(tester);

      expect(find.text('Signed-in devices'), findsOneWidget);
      expect(find.text('Android · app 0.5.0'), findsOneWidget);
      expect(find.textContaining('This device'), findsOneWidget);
      expect(find.text('Web · app 0.5.0'), findsOneWidget);
      expect(find.text('Unknown device'), findsOneWidget);
      expect(find.textContaining('Signed in before devices were listed'),
          findsNWidgets(2));
      // One button per other device, none for this one.
      expect(find.byTooltip('Sign out'), findsNWidgets(2));
      expect(find.text('Sign out all other devices'), findsOneWidget);
    });

    testWidgets('a sign-out asks first', (tester) async {
      var listed = 0;
      when(() => users.listSessions()).thenAnswer((_) async => listed++ == 0
          ? [
              session('phone', current: true),
              session('laptop', client: 'web 0.5.0')
            ]
          : [session('phone', current: true)]);
      when(() => users.revokeSession('laptop')).thenAnswer((_) async {});
      await open(tester);

      await tester.tap(find.byTooltip('Sign out').first);
      await tester.pumpAndSettle();
      expect(find.text('Sign this device out?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
      await tester.pumpAndSettle();

      verify(() => users.revokeSession('laptop')).called(1);
      expect(find.text('Web · app 0.5.0'), findsNothing);
      expect(find.text('Sign out all other devices'), findsNothing);
    });

    testWidgets('cancelling keeps the device', (tester) async {
      when(() => users.listSessions()).thenAnswer(
          (_) async => [session('phone', current: true), session('laptop')]);
      await open(tester);

      await tester.tap(find.text('Sign out all other devices'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => users.revokeOtherSessions());
    });

    testWidgets('without the server, says so and can try again',
        (tester) async {
      var attempts = 0;
      when(() => users.listSessions()).thenAnswer((_) async {
        if (attempts++ == 0) throw SessionsRequestFailure();
        return [session('phone', current: true)];
      });
      await open(tester);

      expect(find.textContaining('this needs a connection'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.textContaining('This device'), findsOneWidget);
    });
  });
}
