import 'package:noports_core/src/common/supported_ssh_clients.dart';
import 'package:noports_core/sshnpd.dart';
import 'package:test/test.dart';
import 'package:args/args.dart';
import 'package:noports_core/src/common/utils.dart';

void main() {
  group('args parser test', () {
    test('test mandatory args', () {
      ArgParser parser = SSHNPDParams.parser;

      List<String> args = [];
      expect(() => parser.parse(args)['atsign'], throwsA(isA<ArgumentError>()));

      args.addAll(['-a', '@bob']);
      expect(parser.parse(args)['atsign'], '@bob');
      expect(
          () => parser.parse(args)['manager'], throwsA(isA<ArgumentError>()));

      args.addAll(['-m', '@alice']);
      expect(parser.parse(args)['atsign'], '@bob');
      expect(parser.parse(args)['manager'], '@alice');
    });

    test('test parsed args with only mandatory provided', () {
      List<String> args = '-a @bob -m @alice'.split(' ');

      var p = SSHNPDParams.fromArgs(args);

      expect(p.deviceAtsign, '@bob');
      expect(p.managerAtsign, '@alice');

      expect(p.device, 'default');
      expect(p.username, getUserName(throwIfNull: true));
      expect(p.homeDirectory, getHomeDirectory(throwIfNull: true));
      expect(p.verbose, false);
      expect(p.atKeysFilePath,
          getDefaultAtKeysFilePath(p.homeDirectory, p.deviceAtsign));
    });

    test('test --ssh-client arg', () {
      expect(SSHNPDParams.fromArgs('-a @bob -m @alice'.split(' ')).sshClient,
          SupportedSshClient.hostSsh);

      expect(
          SSHNPDParams.fromArgs(
                  '-a @bob -m @alice --ssh-client pure-dart'.split(' '))
              .sshClient,
          SupportedSshClient.pureDart);

      expect(
          SSHNPDParams.fromArgs(
                  '-a @bob -m @alice --ssh-client /usr/bin/ssh'.split(' '))
              .sshClient,
          SupportedSshClient.hostSsh);

      expect(
          () => SSHNPDParams.fromArgs(
              '-a @bob -m @alice --ssh-client something-we-do-not-support'
                  .split(' ')),
          throwsA(isA<ArgParserException>()));
    });

    test('test parsed args with non-mandatory args provided', () {
      List<String> args = '-a @bob -m @alice -d device -u -v -s -u'.split(' ');

      var p = SSHNPDParams.fromArgs(args);

      expect(p.deviceAtsign, '@bob');
      expect(p.managerAtsign, '@alice');

      expect(p.device, 'device');
      expect(p.username, getUserName(throwIfNull: true));
      expect(p.homeDirectory, getHomeDirectory(throwIfNull: true));
      expect(p.verbose, true);
      expect(p.atKeysFilePath,
          getDefaultAtKeysFilePath(p.homeDirectory, p.deviceAtsign));
    });
  });
}
