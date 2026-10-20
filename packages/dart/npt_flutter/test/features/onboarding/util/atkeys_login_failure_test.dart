import 'dart:io';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

void main() {
  group('Given signing in with an atKeys file', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('atkeys_login'));
    tearDown(() => dir.deleteSync(recursive: true));

    testWidgets("when the file is cut short so it isn't complete JSON, then"
        " sign-in fails, the dialog's error says the atKeys file isn't valid"
        ' JSON and where it stops, and neither that error nor the app log'
        " contains any of the file's text", (tester) async {
      const value = 'Zm9yLXRlc3Rpbmctb25seS0wMTIzNDU2Nzg5YWJjZGVm';
      final file = File('${dir.path}/@alice_key.atKeys')
        ..writeAsStringSync('{"aesPkamPrivateKey":"$value');
      final logs = await _pumpApp(tester);
      final strings = AppLocalizations.of(App.navState.currentContext!)!;

      final error = await tester.runAsync(() async {
        try {
          await FileAtKeysIo(filePath: (_) => file.path).read('@alice');
        } catch (e) {
          return e;
        }
        return null;
      });
      expect(error, isA<FormatException>(), reason: 'the read the app does');

      final result = NoPortsOnboardingUtil.atKeysLoginFailure(
        '@alice'.toAtsign(),
        error!,
        strings,
      );

      final log = [for (final e in logs.logs) e.loggable.toString()];
      final text = file.readAsStringSync();
      final runs = {
        for (var i = 0; i + 8 <= text.length; i++) text.substring(i, i + 8),
      };
      expect(
        [...log, result.message ?? '']
            .where((t) => runs.any(t.contains)),
        isEmpty,
        reason: "neither the error nor the app log may hold the file's text",
      );
      expect(result.status, NoPortsOnboardingResultStatus.error);
      expect(
        result.message,
        strings.errorAtKeysNotJson(text.length + 1, 'Unterminated string'),
        reason: "the error says the file isn't valid JSON, and where it stops",
      );
      expect(
        log,
        contains('atKeys sign in failed for @alice: ${result.message}'),
        reason: 'the log says the sign-in failed, and why',
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
