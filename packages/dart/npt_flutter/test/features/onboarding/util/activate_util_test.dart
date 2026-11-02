import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart' hide Response;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show Response;
import 'package:http/testing.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/util/activate_util.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

void main() {
  group('Given the activation dialog', () {
    testWidgets("when activating from the registrar's key fails with an error"
        ' whose text holds that key, then the dialog reports the failure and no'
        ' app log line contains the key', (tester) async {
      const key = '0123456789abcdef0123456789abcdef';
      final logs = await _pumpApp(tester);
      final strings = AppLocalizations.of(App.navState.currentContext!)!;
      final util = ActivateUtil(registrarUrl: 'unused', apiKey: 'unused')
        ..activate = (atsign, cramkey, rootDomain) async =>
            throw Exception('refused for $atsign with $cramkey');

      final result = await tester.runAsync(
        () => util.onboardFromCramKey(
          atsign: '@alice'.toAtsign(),
          cramkey: key,
          rootDomain: 'root.atsign.org',
          strings: strings,
        ),
      );

      expect(
        [for (final e in logs.logs) e.loggable.toString()]
            .where((line) => line.contains(key)),
        isEmpty,
        reason: 'no app log line may hold the activation key',
      );
      expect(result!.status, NoPortsOnboardingResultStatus.error);
      expect(
        [for (final e in logs.logs) e.loggable.toString()],
        contains(contains('Failed to onboard @alice')),
        reason: 'the log says the activation failed',
      );
    });
  });

  group('Given the registrar client', () {
    testWidgets("when the registrar doesn't answer a request, then the request"
        ' fails with a TimeoutException after 30 seconds, and not before', (
      tester,
    ) async {
      final util = ActivateUtil(
        registrarUrl: 'unused',
        apiKey: 'unused',
        client: MockClient((_) => Completer<Response>().future),
      );

      Object? outcome;
      unawaited(
        util
            .registrarApiRequest(NoPortsActivateApiEndpoints.login, {
              'atsign': '@alice',
            })
            .then<void>(
              (response) {
                outcome = response;
              },
              onError: (Object e) {
                outcome = e;
              },
            ),
      );

      await tester.pump(const Duration(seconds: 29));
      expect(outcome, isNull, reason: 'the request still waits at 29 seconds');
      await tester.pump(const Duration(seconds: 1));
      expect(
        outcome,
        isA<TimeoutException>(),
        reason: 'the request gives up at 30 seconds',
      );
    });
  });
}

/// Provides the app log [App.log] writes to and the app's strings, and
/// returns the log.
Future<LogsCubit> _pumpApp(WidgetTester tester) async {
  final logs = LogsCubit();
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => EnableLoggingCubit()),
        BlocProvider.value(value: logs),
      ],
      child: MaterialApp(
        navigatorKey: App.navState,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SizedBox(),
      ),
    ),
  );
  return logs;
}
