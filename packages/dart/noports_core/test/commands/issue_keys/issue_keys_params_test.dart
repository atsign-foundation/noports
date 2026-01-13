import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/commands/issue_keys/issue_keys_params.dart';
import 'package:test/test.dart';

class MockAtClient extends Mock implements AtClient {}

class MockEnrollmentService extends Mock implements EnrollmentService {}

class MockEnrollment extends Mock implements Enrollment {}

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

    test('parses atsign with missing device and passphrase', () {
      final params = IssueKeysParams.fromArgs(['-a', '@alice']);
      expect(params.atsign, equals('@alice'));
      expect(params.device, isNull);
      expect(params.passPhrase, isNull);
    });

    test('parses atsign flag with missing device and passphrase', () {
      final params = IssueKeysParams.fromArgs(['--atsign', '@alice']);
      expect(params.atsign, equals('@alice'));
      expect(params.device, isNull);
      expect(params.passPhrase, isNull);
    });

    test('parses device name', () {
      final params = IssueKeysParams.fromArgs([
        '-a',
        '@alice',
        '--device',
        'my-device',
      ]);
      expect(params.device, equals('my-device'));
    });

    test('parses device name flag', () {
      final params = IssueKeysParams.fromArgs([
        '--atsign',
        '@alice',
        '-d',
        'my-device',
      ]);
      expect(params.device, equals('my-device'));
    });

    test('parses key-file', () {
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

    test('parses passphrase', () {
      final params = IssueKeysParams.fromArgs([
        '-a',
        '@alice',
        '--pass-phrase',
        'mypass',
      ]);
      expect(params.passPhrase, equals('mypass'));
    });

    test('parses passphrase flag', () {
      final params = IssueKeysParams.fromArgs(['-a', '@alice', '-P', 'mypass']);
      expect(params.passPhrase, equals('mypass'));
    });

    test('parses verbose flag', () {
      final params = IssueKeysParams.fromArgs(['-a', '@alice', '--verbose']);
      expect(params.verbose, isTrue);
    });

    test('parses debug flag', () {
      final params = IssueKeysParams.fromArgs(['-a', '@alice', '--debug']);
      expect(params.debug, isTrue);
    });
  });
}
