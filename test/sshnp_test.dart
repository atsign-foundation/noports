import 'package:args/args.dart';
import 'package:sshnoports/sshnp.dart';
import 'package:sshnoports/sshnp_utils.dart';
import 'package:test/test.dart';

void main() {
  group('args parser tests', () {
    test('test mandatory args', () {
      ArgParser parser = SSHNP.createArgParser();
      // As of version 2.4.2 of the args package, exceptions regarding
      // mandatory options are not thrown when the args are parsed,
      // but when trying to retrieve a mandatory option.
      // See https://pub.dev/packages/args/changelog

      List<String> args = [];
      expect(() => parser.parse(args)['from'], throwsA(isA<ArgumentError>()));

      args.addAll(['-f','@alice']);
      expect(parser.parse(args)['from'], '@alice');
      expect(() => parser.parse(args)['to'], throwsA(isA<ArgumentError>()));

      args.addAll(['-t','@bob']);
      expect(parser.parse(args)['from'], '@alice');
      expect(parser.parse(args)['to'], '@bob');
      expect(() => parser.parse(args)['host'], throwsA(isA<ArgumentError>()));

      args.addAll(['-h','host.subdomain.test']);
      expect(parser.parse(args)['from'], '@alice');
      expect(parser.parse(args)['to'], '@bob');
      expect(parser.parse(args)['host'], 'host.subdomain.test');
    });

    test('test parsed args with only mandatory provided', () {
      List<String> args = [];
      args.addAll(['-f', '@alice']);
      args.addAll(['-t', '@bob']);
      args.addAll(['-h', 'host.subdomain.test']);
      var p = SSHNP.parseSSHNPParams(args);
      expect(p.clientAtSign, '@alice');
      expect(p.sshnpdAtSign, '@bob');
      expect(p.device, 'default');
      expect(p.host, 'host.subdomain.test');
      expect(p.port, '22');
      expect(p.localPort, '0');
      expect(p.username, getUserName(throwIfNull: true));
      expect(p.homeDirectory, getHomeDirectory(throwIfNull:true));
      expect(p.atKeysFilePath, getDefaultAtKeysFilePath(p.homeDirectory, p.clientAtSign));
      expect(p.sendSshPublicKey, 'false');
      expect(p.localSshOptions, []);
      expect(p.rsa, false);
      expect(p.verbose, false);
      expect(p.remoteUsername, null);
    });
  });
}