import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/features/keys/cubit/enrollment_cubit.dart';
import 'package:noports_config/features/keys/keys_repository.dart';
import 'package:noports_config/platform/daemon_paths.dart';

/// A minimal versioned keyfile as at_auth 4 writes one, less the key
/// material that only the daemon needs (any valid base64 parses).
const _aes =
    '"aesPkamPublicKey":"QUFBQQ==","aesPkamPrivateKey":"QUFBQQ==",'
    '"aesEncryptPublicKey":"QUFBQQ==","aesEncryptPrivateKey":"QUFBQQ==",'
    '"selfEncryptionKey":"QUFBQQ==","apkamSymmetricKey":"QUFBQQ=="';
const _keyfile =
    '{"version":1,"atsign":"@alice","keys":[],"enrollments":[],$_aes}';

/// What `at_activate onboard` still writes: no version, no atsign field.
const _legacyKeyfile = '{$_aes,"enrollmentId":"0000"}';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('np_keys'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File write(String name, String content) =>
      File('${tmp.path}/$name')..writeAsStringSync(content);

  test('inspect reads files the way at_auth does', () {
    final ok = write('anything.atKeys', _keyfile);
    final seen = KeysRepository.inspectSync(ok);
    expect(seen.status, KeysFileStatus.readable);
    expect(seen.atsign, '@alice');
    expect(KeysRepository.atsignOf(ok), '@alice');
    expect(KeysRepository.looksLikeAtKeys(ok), isTrue);

    // A legacy file names no atsign inside; the file name does.
    final legacy = write('@dan_key.atKeys', _legacyKeyfile);
    expect(KeysRepository.inspectSync(legacy).status, KeysFileStatus.readable);
    expect(KeysRepository.inspectSync(legacy).atsign, isNull);
    expect(KeysRepository.atsignOf(legacy), '@dan');

    // Passphrase envelope: recognised, usable with the passphrase, and the
    // atsign comes from the file name.
    final protected = write(
      '@bob_key.atKeys',
      '{"iv":"AAAA","content":"BBBB","version":2}',
    );
    expect(
      KeysRepository.inspectSync(protected).status,
      KeysFileStatus.passphraseNeeded,
    );
    expect(KeysRepository.looksLikeAtKeys(protected), isTrue);
    expect(KeysRepository.atsignOf(protected), '@bob');

    expect(
      KeysRepository.inspectSync(write('x.atKeys', 'not json')).status,
      KeysFileStatus.invalid,
    );
    expect(
      KeysRepository.inspectSync(write('y.atKeys', '{"hello":1}')).status,
      KeysFileStatus.invalid,
    );
    expect(KeysRepository.atsignOf(write('@carol_key.atKeys', '{}')), '@carol');
    expect(KeysRepository.atsignOf(write('z.atKeys', '{}')), isNull);
    expect(
      KeysRepository.inspectSync(File('${tmp.path}/none')).status,
      KeysFileStatus.absent,
    );
  });

  test('a wrong passphrase is reported as such', () async {
    final protected = write(
      '@bob_key.atKeys',
      '{"iv":"AAAA","content":"BBBB","version":2}',
    );
    final seen = await KeysRepository.inspect(protected, passPhrase: 'nope');
    expect(seen.status, KeysFileStatus.wrongPassphrase);
    expect(
      (await KeysRepository.inspect(protected)).status,
      KeysFileStatus.passphraseNeeded,
    );
  });

  test(
    'import copies into the managed directory and never overwrites',
    () async {
      final paths = DaemonPaths.forTest(
        configDir: Directory('${tmp.path}/etc'),
        binDir: Directory('${tmp.path}/bin'),
        userHomeDir: Directory('${tmp.path}/home'),
      );
      final repo = KeysRepository(paths: paths);
      final source = write('from-usb.atKeys', _keyfile);

      final dest = await repo.import(source, '@alice');
      expect(dest.path, paths.keysFileFor('@alice').path);
      expect(dest.readAsStringSync(), _keyfile);
      if (!Platform.isWindows) {
        final mode = Process.runSync('stat', [
          Platform.isMacOS ? '-f' : '-c',
          Platform.isMacOS ? '%Lp' : '%a',
          dest.path,
        ]).stdout.toString().trim();
        expect(mode, '600', reason: 'restrictPermissions');
      }

      // Same content again: fine. Different content: refused, file untouched.
      expect((await repo.import(source, '@alice')).path, dest.path);
      final other = write(
        'other.atKeys',
        _keyfile.replaceFirst('@alice', '@alicf'),
      );
      await expectLater(
        repo.import(other, '@alice'),
        throwsA(isA<KeysException>()),
      );
      expect(dest.readAsStringSync(), _keyfile);

      await expectLater(
        repo.import(File('${tmp.path}/missing'), '@alice'),
        throwsA(isA<KeysException>()),
      );
      await expectLater(
        repo.import(write('bad.atKeys', '{}'), '@alice'),
        throwsA(isA<KeysException>()),
      );
    },
  );

  test('enrollment refuses bad input before touching the network', () async {
    final paths = DaemonPaths.forTest(
      configDir: Directory('${tmp.path}/etc'),
      binDir: Directory('${tmp.path}/bin'),
      userHomeDir: Directory('${tmp.path}/home'),
    );
    final cubit = EnrollmentCubit(rootDomain: 'root.atsign.org', paths: paths);
    await cubit.enroll(rawAtsign: 'al!ce', deviceName: 'pc', passcode: 'X');
    expect(cubit.state.error, contains('not a valid atsign'));
    expect(cubit.state.step, EnrollmentStep.enterDetails);

    await cubit.enroll(rawAtsign: 'alice', deviceName: 'A', passcode: 'X');
    expect(cubit.state.error, contains('Device name "a" is not allowed'));

    await cubit.enroll(rawAtsign: 'alice', deviceName: '-pc', passcode: 'X');
    expect(cubit.state.error, contains('not allowed'));

    await cubit.enroll(rawAtsign: 'alice', deviceName: 'My PC', passcode: '');
    expect(cubit.state.error, 'The passcode is required.');
    expect(paths.keysDir.existsSync(), isFalse, reason: 'nothing written');
    await cubit.close();
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
