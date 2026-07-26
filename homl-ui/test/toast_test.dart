import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/helpers/toast.dart';

/// App shell with the same toast wiring as the real one: the messenger sits
/// above the navigator and the route observer clears the toasts on navigation.
class _TestApp extends StatelessWidget {
  const _TestApp();

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: messengerKey,
      navigatorKey: navigatorKey,
      navigatorObservers: [ToastRouteObserver(messengerKey)],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                    onPressed: () => showToast(context, 'first'),
                    child: const Text('show first')),
                TextButton(
                    onPressed: () => showToast(context, 'second'),
                    child: const Text('show second')),
                TextButton(
                    onPressed: () => dismissToasts(context),
                    child: const Text('dismiss')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('a tap on the toast dismisses it', (tester) async {
    await tester.pumpWidget(const _TestApp());

    await tester.tap(find.text('show first'));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);

    await tester.tap(find.text('first'));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsNothing);
  });

  testWidgets('a new toast replaces the previous one instead of queueing',
      (tester) async {
    await tester.pumpWidget(const _TestApp());

    await tester.tap(find.text('show first'));
    await tester.pump();
    await tester.tap(find.text('show second'));
    await tester.pumpAndSettle();

    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);

    // The replaced toast must not come back once the new one is gone: queued
    // toasts used to play one after another, outliving their screen.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsNothing);
  });

  testWidgets('a route change clears the toast', (tester) async {
    await tester.pumpWidget(const _TestApp());

    await tester.tap(find.text('show first'));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);

    unawaited(_TestApp.navigatorKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('elsewhere')))));
    await tester.pumpAndSettle();

    expect(find.text('first'), findsNothing);
    expect(find.text('elsewhere'), findsOneWidget);
  });

  testWidgets('a toast shown right after a navigation survives it',
      (tester) async {
    await tester.pumpWidget(const _TestApp());

    final messenger = _TestApp.messengerKey.currentState!;
    unawaited(_TestApp.navigatorKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('elsewhere')))));
    showToastWith(messenger, 'saved');
    await tester.pumpAndSettle();

    expect(find.text('saved'), findsOneWidget);
  });
}
