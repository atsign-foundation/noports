import 'package:args/args.dart';
import 'package:sshnoports/sshnp.dart';
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
  });
}