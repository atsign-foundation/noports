import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/widgets/progress_indicator_dialog.dart';

void main() {
  final navigator = GlobalKey<NavigatorState>();

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      home: const Scaffold(body: Text('home')),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the indicator is up while the task runs, and removed when it '
      'completes', (tester) async {
    await pumpApp(tester);
    final task = Completer<String>();

    final result = runWithProgressIndicator(
      navigator.currentContext!,
      () => task.future,
    );
    await settle(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    task.complete('done');
    await settle(tester);

    expect(await result, 'done');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('the indicator is removed when the task fails', (tester) async {
    await pumpApp(tester);
    final task = Completer<String>();

    final result = runWithProgressIndicator(
      navigator.currentContext!,
      () => task.future,
    );
    await settle(tester);
    task.completeError(StateError('failed'));
    await expectLater(result, throwsStateError);
    await settle(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a route pushed above the indicator stays when the indicator is '
      'removed', (tester) async {
    await pumpApp(tester);
    final task = Completer<void>();

    final result = runWithProgressIndicator(
      navigator.currentContext!,
      () => task.future,
    );
    await settle(tester);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('above')),
      ),
    );
    await settle(tester);

    task.complete();
    await result;
    await settle(tester);

    expect(
      find.byType(CircularProgressIndicator, skipOffstage: false),
      findsNothing,
    );
    expect(find.text('above'), findsOneWidget);
  });
}
