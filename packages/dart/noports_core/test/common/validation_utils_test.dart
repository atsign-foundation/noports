import 'package:noports_core/src/common/validation_utils.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('isValidSessionId', () {
    const fixedUuid = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

    test('accepts the UUIDs clients generate', () {
      final generated = Uuid().v4();
      expect(isValidSessionId(generated), isTrue);
      expect(isValidSessionId(generated.toUpperCase()), isTrue);
    });

    test('accepts a UUID of any version', () {
      expect(isValidSessionId(fixedUuid), isTrue);
    });

    test('refuses anything else', () {
      for (final v in [
        '',
        'ssh',
        'abc',
        'abc\nssh-ed25519 AAAAattackerKey attacker',
        '$fixedUuid\n',
        '\n$fixedUuid',
        '$fixedUuid\r',
        '$fixedUuid ',
        ' $fixedUuid',
        '{$fixedUuid}',
        fixedUuid.replaceAll('-', ''),
        '../../$fixedUuid',
        'g${fixedUuid.substring(1)}',
      ]) {
        expect(isValidSessionId(v), isFalse, reason: 'accepted "$v"');
      }
    });

    test('refuses a value which is not a String', () {
      expect(isValidSessionId(null), isFalse);
      expect(isValidSessionId(42), isFalse);
      expect(isValidSessionId([fixedUuid]), isFalse);
    });
  });

  group('assertValidSessionId', () {
    test('passes a UUID', () {
      assertValidSessionId(Uuid().v4());
    });

    test('throws an ArgumentError naming sessionId for anything else', () {
      expect(
        () => assertValidSessionId('ssh'),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'sessionId'),
        ),
      );
    });
  });
}
