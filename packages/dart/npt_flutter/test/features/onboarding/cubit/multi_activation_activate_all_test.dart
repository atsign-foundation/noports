import 'dart:io';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/cubit/multi_activation_cubit.dart';
import 'package:npt_flutter/features/onboarding/model/multi_activation_file_content.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

/// Bulk activation against an atServer that has every atsign waiting to be
/// activated, where activating one fails with an error naming its key.
class _RefusingActivation extends MultiActivationCubit {
  @override
  Future<AtSignServerState> atServerState(Atsign atsign) async =>
      AtSignServerState.notActivated;

  @override
  Future<void> activateIntoKeychain(Atsign atsign, String cramSecret) async =>
      throw Exception('refused for $atsign with $cramSecret');
}

void main() {
  group('Given bulk activation of an activation file', () {
    const key = '0123456789abcdef0123456789abcdef';
    late Directory dir;
    late _RefusingActivation cubit;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('bulk_activation');
      cubit = _RefusingActivation()..backupDirectory = dir.path;
    });

    tearDown(() {
      cubit.close();
      dir.deleteSync(recursive: true);
    });

    testWidgets("when an entry's activation fails with an error whose text"
        ' holds its activation key, then the entry is marked failed and no app'
        ' log line contains the key', (tester) async {
      final logs = await _pumpApp(tester);
      final file = File('${dir.path}/activation.yaml')
        ..writeAsStringSync('atsigns:\n  - "@one_jttest:activation_key:$key"\n');
      await tester.runAsync(() async {
        await cubit.processFile(file.path, 'activation.yaml');
        await cubit.activateAll();
      });

      final log = [for (final e in logs.logs) e.loggable.toString()];
      expect(
        log.where((line) => line.contains(key)),
        isEmpty,
        reason: 'no app log line may hold the activation key',
      );
      expect(
        cubit.state.fileContent.entries.single.activationKeyStatus,
        ActivationKeyStatus.failed,
      );
      expect(
        log,
        contains(contains('Exception activating @one_jttest')),
        reason: 'the log says which atsign failed to activate',
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
