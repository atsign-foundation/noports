import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/features/keys/cubit/enrollment_cubit.dart';
import 'package:noports_config/features/keys/keys_repository.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('np_keys'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('atsignOf reads at_auth 4 files, legacy files and the file name', () {
    final v4 = File('${tmp.path}/anything.atKeys')
      ..writeAsStringSync('{"atsign":"@Alice","aesPkamPrivateKey":"x"}');
    expect(KeysRepository.atsignOf(v4), '@alice');
    final legacy = File('${tmp.path}/legacy.atKeys')
      ..writeAsStringSync('{"aesPkamPrivateKey":"x","@bob":"enc"}');
    expect(KeysRepository.atsignOf(legacy), '@bob');
    final byName = File('${tmp.path}/@carol_key.atKeys')
      ..writeAsStringSync('not json');
    expect(KeysRepository.atsignOf(byName), '@carol');
    final unknown = File('${tmp.path}/x.atKeys')..writeAsStringSync('{}');
    expect(KeysRepository.atsignOf(unknown), isNull);
  });

  test('enrollment errors are explained', () {
    expect(
      EnrollmentCubit.describeError(
        Exception(
          'ErrorCode: AT0032 - Exception: Exception: Another enrollment with id '
          '6927-1090 exists with the app name: noports and device name: tarial '
          'in approved state',
        ),
      ),
      allOf(contains('tarial'), contains('different device name')),
    );
    expect(
      EnrollmentCubit.describeError(
        Exception(
          'Connecting to root.atsign.org:64 : HandshakeException: Handshake '
          'error in client (OS Error: CERTIFICATE_VERIFY_FAILED: unable to '
          'get local issuer certificate)',
        ),
      ),
      contains('ca-certificates'),
    );
    expect(
      EnrollmentCubit.describeError(Exception('enrollment request denied')),
      contains('denied'),
    );
  });
}
