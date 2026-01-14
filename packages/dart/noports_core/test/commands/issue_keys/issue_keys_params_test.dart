import 'package:noports_core/src/commands/issue_keys/issue_keys_params.dart';
import 'package:test/test.dart';

void main() {
  group('IssueKeysParams', () {
    test('throws for missing args', () {
      expect(() => IssueKeysParams.fromArgs([]), throwsA(isA<ArgumentError>()));
    });

    test('throws for missing atsign', () {
      final args = ['--device', 'my-device'];
      expect(
        () => IssueKeysParams.fromArgs(args),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('parses atsign short flag', () {
      final params = IssueKeysParams.fromArgs(['-a', '@alice']);
      expect(params.atsign, equals('@alice'));
    });

    test('parses atsign long flag', () {
      final params = IssueKeysParams.fromArgs(['--atsign', '@alice']);
      expect(params.atsign, equals('@alice'));
    });

    test('parses device name long flag', () {
      final params = IssueKeysParams.fromArgs([
        '-a',
        '@alice',
        '--device',
        'my-device',
      ]);
      expect(params.device, equals('my-device'));
    });

    test('parses device name short flag', () {
      final params = IssueKeysParams.fromArgs([
        '--atsign',
        '@alice',
        '-d',
        'my-device',
      ]);
      expect(params.device, equals('my-device'));
    });

    test('parses key-file long flag', () {
      final params = IssueKeysParams.fromArgs([
        '-a',
        '@alice',
        '--key-file',
        'path/to/keyfile',
      ]);
      expect(params.atKeysFilePath, equals('path/to/keyfile'));
    });

    test('parses key-file short flag', () {
      final params = IssueKeysParams.fromArgs([
        '-a',
        '@alice',
        '-k',
        'path/to/keyfile',
      ]);
      expect(params.atKeysFilePath, equals('path/to/keyfile'));
    });

    test('parses passphrase long flag', () {
      final params = IssueKeysParams.fromArgs([
        '-a',
        '@alice',
        '--pass-phrase',
        'mypass',
      ]);
      expect(params.passPhrase, equals('mypass'));
    });

    test('parses passphrase short flag', () {
      final params = IssueKeysParams.fromArgs(['-a', '@alice', '-P', 'mypass']);
      expect(params.passPhrase, equals('mypass'));
    });

    test('parses verbose long flag', () {
      final params = IssueKeysParams.fromArgs(['-a', '@alice', '--verbose']);
      expect(params.verbose, isTrue);
    });

    test('parses verbose short flag', () {
      final params = IssueKeysParams.fromArgs(['-a', '@alice', '-v']);
      expect(params.verbose, isTrue);
    });

    test('parses debug long flag', () {
      final params = IssueKeysParams.fromArgs(['-a', '@alice', '--debug']);
      expect(params.debug, isTrue);
    });
  });
}
