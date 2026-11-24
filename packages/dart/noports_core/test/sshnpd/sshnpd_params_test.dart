import 'dart:io';

import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/common/validation_utils.dart';
import 'package:noports_core/src/sshnpd/sshnpd_params.dart';
import 'package:test/test.dart';

void main() {
  group('test sshnpd params defaults', () {
    test(
      'require at least one of managers and policyManager options',
      () async {
        List<String> args = '-a @daemon'.split(' ');
        await expectLater(
          () => SshnpdParams.fromArgs(args),
          throwsA(TypeMatcher<ArgumentError>()),
        );
      },
    );
    test('just managers option supplied', () async {
      List<String> args = '-a @daemon -m @bob'.split(' ');
      final p = await SshnpdParams.fromArgs(args);
      expect(p.managerAtsigns, ['@bob']);
    });
    test('just policyManager option supplied', () async {
      List<String> args = '-a @daemon -p @bob'.split(' ');
      final p = await SshnpdParams.fromArgs(args);
      expect(p.policyManagerAtsign, '@bob');
      expect(p.managerAtsigns, []);
    });
    test('both managers and policyManager options supplied', () async {
      List<String> args = '-a @daemon -m @bob,@chuck -p @policy'.split(' ');
      final p = await SshnpdParams.fromArgs(args);
      expect(p.deviceAtsign, '@daemon');
      expect(p.policyManagerAtsign, '@policy');
      expect(p.managerAtsigns, ['@bob', '@chuck']);
    });
    test('test permitOpen default without policyManager', () async {
      List<String> args = '-a @daemon -m @bob'.split(' ');
      SshnpdParams p = await SshnpdParams.fromArgs(args);
      expect(p.permitOpen, DefaultSshnpdArgs.permitOpen);
    });
    test('test permitOpen default with policyManager', () async {
      List<String> args = '-a @daemon -p @policy'.split(' ');
      SshnpdParams p = await SshnpdParams.fromArgs(args);
      expect(p.permitOpen, '*:*');
    });
    test('test permitOpen provided without policyManager', () async {
      final po = 'host1.sub.net:12345,host2.sub.net:34567,localhost:3000';
      List<String> args = '-a @daemon -m @bob --permit-open $po'.split(' ');
      SshnpdParams p = await SshnpdParams.fromArgs(args);
      expect(p.permitOpen, po);
    });
    test('test permitOpen provided with policyManager', () async {
      final po = 'host1.sub.net:12345,host2.sub.net:34567,localhost:3000';
      List<String> args = '-a @daemon -p @policy --permit-open $po'.split(' ');
      SshnpdParams p = await SshnpdParams.fromArgs(args);
      expect(p.permitOpen, po);
    });
    test('test strict mode default true when using policy service', () async {
      List<String> args = '-a @daemon -p @policy'.split(' ');
      final p = await SshnpdParams.fromArgs(args);
      expect(p.strict, true);
    });
    test('test strict mode explicitly false when would default to true', () async {
      List<String> args = '-a @daemon -p @policy --no-strict'.split(' ');
      final p = await SshnpdParams.fromArgs(args);
      expect(p.strict, false);
    });
    test('test strict mode default false when not using policy service', () async {
      List<String> args = '-a @daemon -m @bob'.split(' ');
      final p = await SshnpdParams.fromArgs(args);
      expect(p.strict, false);
    });
    test('checks client enrollments every 10 seconds by default, and does not'
        ' require enrollment signatures', () async {
      final p = await SshnpdParams.fromArgs('-a @daemon -m @bob'.split(' '));
      expect(p.clientKeyCheckSecs, 10);
      expect(p.requireEnrollmentSignature, isFalse);
    });
    test('takes --client-key-check-secs, with 0 turning the check off',
        () async {
      for (final secs in [0, 1, 30]) {
        final p = await SshnpdParams.fromArgs(
          '-a @daemon -m @bob --client-key-check-secs $secs'.split(' '),
        );
        expect(p.clientKeyCheckSecs, secs);
      }
    });
    test('refuses a negative --client-key-check-secs', () async {
      await expectLater(
        () => SshnpdParams.fromArgs(
          '-a @daemon -m @bob --client-key-check-secs -1'.split(' '),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
    test('takes --require-enrollment-signature', () async {
      final p = await SshnpdParams.fromArgs(
        '-a @daemon -m @bob --require-enrollment-signature'.split(' '),
      );
      expect(p.requireEnrollmentSignature, isTrue);
    });
    test('test strict mode explicitly true when would default to false', () async {
      List<String> args = '-a @daemon -m @manager --strict'.split(' ');
      final p = await SshnpdParams.fromArgs(args);
      expect(p.strict, true);
    });
    test('joins the --sshpublickey-permissions values with commas', () async {
      final p = await SshnpdParams.fromArgs([
        ...'-a @daemon -m @bob -S no-pty'.split(' '),
        ...['-S', 'command="echo hi" , , no-X11-forwarding,'],
      ]);
      expect(
        p.sshPublicKeyPermissions,
        'no-pty,command="echo hi",no-X11-forwarding',
      );
    });
    test('refuses a --sshpublickey-permissions value holding a newline',
        () async {
      for (final String permissions in ['no-pty\nssh-ed25519 x', 'a\rb']) {
        await expectLater(
          () => SshnpdParams.fromArgs(
            [...'-a @daemon -m @bob -S'.split(' '), permissions],
          ),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            invalidSshKeyPermissionsMsg,
          )),
          reason: permissions,
        );
      }
    });
    test('passes a from option in --sshpublickey-permissions on to sshnpd',
        () async {
      final p = await SshnpdParams.fromArgs(
        [...'-a @daemon -m @bob -S'.split(' '), 'no-pty,FROM="10.0.0.0/8"'],
      );
      expect(p.sshPublicKeyPermissions, 'no-pty,FROM="10.0.0.0/8"');
    });
    test(
        'passes a from option in the config file\'s publickey-permissions on to sshnpd',
        () async {
      final Directory dir = Directory.systemTemp.createTempSync('sshnpd_cfg');
      addTearDown(() => dir.deleteSync(recursive: true));
      final File config = File('${dir.path}/sshnpd.yaml')
        ..writeAsStringSync(
          'ssh:\n'
          '  publickey-permissions:\n'
          '    - no-pty\n'
          '    - from="10.0.0.0/8"\n',
        );

      final p = await SshnpdParams.fromArgs(
        ['-a', '@daemon', '-m', '@bob', '--config', config.path],
      );
      expect(p.sshPublicKeyPermissions, 'no-pty,from="10.0.0.0/8"');
    });
    // TODO add unit tests for other mildly complicated options
    // device
    // storage-path
    // key-file
    // local-sshd-port
    // sshpublickey-permissions
  });
}
