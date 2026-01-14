import 'package:noports_core/commands.dart';
import 'package:noports_core/src/commands/activate/activate_params.dart';
import 'package:test/test.dart';

void main() {
  group('validate negative cases for ActivateParams', () {
    test('throws ArgumentError for empty args', () {
      expect(() => ActivateParams.fromArgs([]), throwsA(isA<ArgumentError>()));
    });

    test('throws HelpRequestedException for --help flag', () {
      expect(
        () => ActivateParams.fromArgs(['--help']),
        throwsA(isA<HelpRequestedException>()),
      );
    });

    test('throws ArgumentError for missing activation string', () {
      expect(
        () => ActivateParams.fromArgs(['--target-keyfile', 'test.atKeys']),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Activation string is required'),
          ),
        ),
      );
    });

    test('throws ArgumentError for invalid activation type', () {
      expect(
        () => ActivateParams.fromArgs(['@alice:invalid:test']),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Invalid activation type'),
          ),
        ),
      );
    });

    test('throws ArgumentError for missing atsign in CRAM', () {
      expect(
        () => ActivateParams.fromArgs([':cram:secret']),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('atsign is required'),
          ),
        ),
      );
    });
  });

  group('ActivateType cram - positive cases', () {
    test('parses valid CRAM activation string', () {
      final params = ActivateParams.fromArgs(['@alice:cram:testsecret']);

      expect(params.atsign.toString(), equals('@alice'));
      expect(params.type, equals(ActivateType.cram));
      expect(params.cramSecret, equals('testsecret'));
      expect(params.otp, isNull);
      expect(params.deviceName, isNull);
    });

    test('parses CRAM with target keyfile', () {
      final params = ActivateParams.fromArgs([
        '--target-keyfile',
        'test.atKeys',
        '@alice:cram:testsecret',
      ]);

      expect(params.atKeysFilePath, equals('test.atKeys'));
    });

    test('parses CRAM with verbose flag', () {
      final params = ActivateParams.fromArgs([
        '--verbose',
        '@alice:cram:testsecret',
      ]);

      expect(params.verbose, isTrue);
      expect(params.debug, isFalse);
    });

    test('parses CRAM with debug flag', () {
      final params = ActivateParams.fromArgs([
        '--debug',
        '@alice:cram:testsecret',
      ]);

      expect(params.debug, isTrue);
      expect(params.verbose, isFalse);
    });
  });

  group('ActivateType enrollment - positive cases', () {
    test('parses valid enrollment string with OTP', () {
      final params = ActivateParams.fromArgs(['@alice:enroll:otp:123456']);

      expect(params.atsign.toString(), equals('@alice'));
      expect(params.type, equals(ActivateType.enroll));
      expect(params.otp, equals('123456'));
      expect(params.cramSecret, isNull);
      expect(params.deviceName, isNull);
    });

    test('parses enrollment with device name', () {
      final params = ActivateParams.fromArgs([
        '@alice:enroll:otp:123456:name:my-device',
      ]);

      expect(params.deviceName, equals('my-device'));
    });

    test('parses enrollment with target keyfile', () {
      final params = ActivateParams.fromArgs([
        '--target-keyfile',
        'enroll.atKeys',
        '@alice:enroll:otp:123456',
      ]);

      expect(params.atKeysFilePath, equals('enroll.atKeys'));
    });
  });

  group('validate ActivateType enum', () {
    test('parse returns correct type for CRAM', () {
      expect(
        ActivateType.parse('@test:cram:secret'),
        equals(ActivateType.cram),
      );
    });

    test('parse returns correct type for enroll', () {
      expect(
        ActivateType.parse('@test:enroll:otp:123456'),
        equals(ActivateType.enroll),
      );
    });

    test('parse throws for invalid type', () {
      expect(
        () => ActivateType.parse('@test:invalid:value'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Regex Validation', () {
    test('validates correct CRAM format', () {
      final params = ActivateParams.fromArgs(['@alice:cram:test-secret_123']);
      expect(params.atsign.toString(), equals('@alice'));
      expect(params.cramSecret, equals('test-secret_123'));
      expect(params.type, equals(ActivateType.cram));
    });

    test('validates atsign parsing - atsign missing @', () {
      final cram = 'kljdfksdjbfksdbksd1234';
      final params = ActivateParams.fromArgs(['alice:cram:$cram']);
      expect(params.atsign.toString(), equals('@alice'));
      expect(params.cramSecret, equals(cram));
      expect(params.type, equals(ActivateType.cram));
    });

    test('validates correct enrollment format with OTP', () {
      final params = ActivateParams.fromArgs(['@bob:enroll:otp:123456']);
      expect(params.atsign.toString(), equals('@bob'));
      expect(params.otp, equals('123456'));
      expect(params.type, equals(ActivateType.enroll));
    });

    test('validates correct enrollment format: atsign missing @', () {
      final params = ActivateParams.fromArgs(['bob:enroll:otp:123456']);
      expect(params.atsign.toString(), equals('@bob'));
      expect(params.otp, equals('123456'));
      expect(params.type, equals(ActivateType.enroll));
    });

    test('validates enrollment with device name', () {
      final params = ActivateParams.fromArgs([
        '@bob:enroll:otp:123456:name:my-device',
      ]);
      expect(params.deviceName, equals('my-device'));
    });

    test('case: invalid CRAM format (missing secret)', () {
      expect(
        () => ActivateParams.fromArgs(['@alice:cram:']),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('case: invalid enrollment format (invalid OTP)', () {
      expect(
        () => ActivateParams.fromArgs(['@bob:enroll:otp:123']),
        // OTP too short
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
