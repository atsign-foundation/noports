import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/sshnpd/sshnpd_params.dart';
import 'package:test/test.dart';

void main() {
  group('test sshnpd params defaults', () {
    test('require at least one of managers and policyManager options',
        () async {
      List<String> args = '-a @daemon'.split(' ');
      await expectLater(() => SshnpdParams.fromArgs(args),
          throwsA(TypeMatcher<ArgumentError>()));
    });
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
    // TODO add unit tests for other mildly complicated options
    // device
    // storage-path
    // key-file
    // local-sshd-port
    // sshpublickey-permissions
  });
}
