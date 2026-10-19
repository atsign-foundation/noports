import 'dart:io';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/cubit/multi_activation_cubit.dart';
import 'package:npt_flutter/features/onboarding/model/multi_activation_file_content.dart';

ActivationKeyPair entry(String atsign, ActivationKeyStatus status) {
  return ActivationKeyPair(
    atsign: atsign.toAtsign(),
    activationKey: 'a' * 128,
    activationKeyStatus: status,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('areEntriesSettled', () {
    test('is false while an entry is still waiting', () {
      expect(
        MultiActivationCubit.areEntriesSettled([
          entry('@one', ActivationKeyStatus.activated),
          entry('@two', ActivationKeyStatus.waiting),
        ]),
        isFalse,
      );
    });

    test('is false while an entry is mid-flight', () {
      expect(
        MultiActivationCubit.areEntriesSettled([
          entry('@one', ActivationKeyStatus.activated),
          entry('@two', ActivationKeyStatus.activating),
        ]),
        isFalse,
      );
    });

    test('is true once every entry is activated or failed', () {
      expect(
        MultiActivationCubit.areEntriesSettled([
          entry('@one', ActivationKeyStatus.activated),
          entry('@two', ActivationKeyStatus.alreadyActivated),
          entry('@three', ActivationKeyStatus.failed),
        ]),
        isTrue,
      );
    });

    test('is true for an empty list', () {
      expect(MultiActivationCubit.areEntriesSettled([]), isTrue);
    });
  });

  group('signInAtsignFor', () {
    test('skips a trailing failure and picks the last activated atsign', () {
      expect(
        MultiActivationCubit.signInAtsignFor([
          entry('@one', ActivationKeyStatus.activated),
          entry('@two', ActivationKeyStatus.activated),
          entry('@three', ActivationKeyStatus.failed),
        ]),
        equals('@two'.toAtsign()),
      );
    });

    test('accepts an already activated atsign', () {
      expect(
        MultiActivationCubit.signInAtsignFor([
          entry('@one', ActivationKeyStatus.failed),
          entry('@two', ActivationKeyStatus.alreadyActivated),
        ]),
        equals('@two'.toAtsign()),
      );
    });

    test('is null when nothing activated', () {
      expect(
        MultiActivationCubit.signInAtsignFor([
          entry('@one', ActivationKeyStatus.failed),
          entry('@two', ActivationKeyStatus.failed),
        ]),
        isNull,
      );
    });
  });

  group('resetFailedEntries', () {
    test('returns failed entries to waiting and clears their reason', () {
      final failed = entry(
        '@one',
        ActivationKeyStatus.failed,
      ).copyWith(failureReason: 'atServer unreachable');

      final result = MultiActivationCubit.resetFailedEntries([
        failed,
        entry('@two', ActivationKeyStatus.activated),
      ]);

      expect(result[0].activationKeyStatus, ActivationKeyStatus.waiting);
      expect(result[0].failureReason, isNull);
      expect(result[0].activationKey, equals(failed.activationKey));
    });

    test('leaves activated entries alone so a retry does not redo them', () {
      final result = MultiActivationCubit.resetFailedEntries([
        entry('@one', ActivationKeyStatus.activated),
        entry('@two', ActivationKeyStatus.alreadyActivated),
      ]);

      expect(result[0].activationKeyStatus, ActivationKeyStatus.activated);
      expect(
        result[1].activationKeyStatus,
        ActivationKeyStatus.alreadyActivated,
      );
    });
  });

  group('isActivationComplete', () {
    late MultiActivationCubit cubit;
    late Directory tempDir;

    setUp(() {
      cubit = MultiActivationCubit();
      tempDir = Directory.systemTemp.createTempSync('multi_activation_test');
    });

    tearDown(() {
      cubit.close();
      tempDir.deleteSync(recursive: true);
    });

    test('is true before a file is uploaded', () {
      expect(cubit.isActivationComplete(), isTrue);
    });

    test('is false once a file of waiting atsigns is loaded', () async {
      final file = File('${tempDir.path}/activation.yaml');
      file.writeAsStringSync(
        'atsigns:\n'
        '  - "@one_jttest:activation_key:${'a' * 128}"\n'
        '  - "@two_jttest:activation_key:${'b' * 128}"\n',
      );

      await cubit.processFile(file.path, 'activation.yaml');

      expect(cubit.state.fileContent.entries, hasLength(2));
      expect(
        cubit.state.fileContent.entries.first.atsign,
        equals('@one_jttest'.toAtsign()),
      );
      expect(cubit.isActivationComplete(), isFalse);
    });
  });

  group('onboardTimeout', () {
    test('is far below the 5 minute provisioning budget default', () {
      // A file of dud atsigns used to sit on the activating screen for
      // 5 minutes each because activation polled for provisioning that was
      // never coming.
      expect(
        MultiActivationCubit.onboardTimeout,
        lessThan(const Duration(minutes: 5)),
      );
    });
  });

  group('Given the bulk-activation dialog and a chosen activation file', () {
    const key = '0123456789abcdef0123456789abcdef';
    late MultiActivationCubit cubit;
    late Directory tempDir;

    setUp(() {
      cubit = MultiActivationCubit();
      tempDir = Directory.systemTemp.createTempSync('multi_activation_test');
    });

    tearDown(() {
      cubit.close();
      tempDir.deleteSync(recursive: true);
    });

    /// Uploads an activation file holding [content], returning the app log.
    Future<List<String>> upload(WidgetTester tester, String content) async {
      final logs = await _pumpAppLog(tester);
      final file = File('${tempDir.path}/activation.yaml')
        ..writeAsStringSync(content);
      await tester.runAsync(
        () => cubit.processFile(file.path, 'activation.yaml'),
      );
      return [for (final entry in logs.logs) entry.loggable.toString()];
    }

    testWidgets('when an entry lacks its activation_key part, then the upload'
        ' is refused, the app log says which entry could not be read by its'
        ' position, and no app log line contains the key', (tester) async {
      final log = await upload(
        tester,
        'atsigns:\n'
        '  - "@one_jttest:activation_key:${'a' * 32}"\n'
        '  - "@two_jttest:$key"\n',
      );

      expect(cubit.state.uploadState, MultiActivationFileUploadState.error);
      expect(
        log,
        contains(contains('entry 2')),
        reason: 'the log names the entry that could not be read',
      );
      expect(
        log.where((line) => line.contains(key)),
        isEmpty,
        reason: 'no app log line may hold an activation key',
      );
    });

    testWidgets("when an entry isn't text, then the upload is refused and the"
        ' app log says which entry could not be read by its position',
        (tester) async {
      final log = await upload(
        tester,
        'atsigns:\n'
        '  - "@one_jttest:activation_key:$key"\n'
        '  - 42\n',
      );

      expect(cubit.state.uploadState, MultiActivationFileUploadState.error);
      expect(
        log,
        contains(contains('entry 2')),
        reason: 'the log names the entry that could not be read',
      );
    });

    testWidgets("when the file isn't valid YAML on an entry's line, then the"
        " upload is refused, the app log says the file isn't valid YAML and"
        " gives the line number, and no app log line contains that line's"
        ' text', (tester) async {
      final log = await upload(
        tester,
        'atsigns:\n'
        '  - @one_jttest:activation_key:$key\n',
      );

      expect(cubit.state.uploadState, MultiActivationFileUploadState.error);
      expect(
        log,
        contains(allOf(contains('YAML'), contains('line 2'))),
        reason: "the log says the file isn't valid YAML, and where",
      );
      expect(
        log.where((line) => line.contains(key)),
        isEmpty,
        reason: 'no app log line may hold an activation key',
      );
    });

    testWidgets('when every entry is well formed, then the upload succeeds as'
        ' before', (tester) async {
      final log = await upload(
        tester,
        'atsigns:\n'
        '  - "@one_jttest:activation_key:$key"\n',
      );

      expect(cubit.state.uploadState, MultiActivationFileUploadState.success);
      expect(cubit.state.fileContent.entries.single.activationKey, key);
      expect(
        log,
        contains('uploaded activation file content successfully'),
      );
    });
  });
}

/// Provides the app log [App.log] writes to, and returns it.
Future<LogsCubit> _pumpAppLog(WidgetTester tester) async {
  final logs = LogsCubit();
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => EnableLoggingCubit()),
        BlocProvider.value(value: logs),
      ],
      child: MaterialApp(navigatorKey: App.navState, home: const SizedBox()),
    ),
  );
  return logs;
}
