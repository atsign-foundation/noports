import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:flutter_test/flutter_test.dart';
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
    test('is far below the 5 minute AtAuth onboarding poll default', () {
      // A file of dud atsigns used to sit on the activating screen for
      // 5 minutes each because AtAuth polled for provisioning that was never
      // coming.
      expect(
        MultiActivationCubit.onboardTimeout,
        lessThan(const Duration(minutes: 5)),
      );
    });
  });
}
