import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sshnoports/src/create_at_client_cli.dart';
import 'package:test/test.dart';

class _MockAtClient extends Mock implements AtClient {}

_MockAtClient _clientWhoseAttempts(AtConnectionState Function() answer) {
  final client = _MockAtClient();
  final connection = AtConnection(
    atSign: '@alice',
    attempt: (_) async => answer(),
  );
  when(() => client.connection).thenReturn(connection);
  when(() => client.stop()).thenAnswer((_) async {});
  return client;
}

void main() {
  group('onlineOrThrow', () {
    test('returns once the client is online', () async {
      final client = _clientWhoseAttempts(() => AtConnectionState.online());
      await onlineOrThrow(client, '@alice', const Duration(seconds: 1));
      verifyNever(() => client.stop());
    });

    test(
        'a refusal on a device that has been online before is an '
        'authentication failure carrying the atServer\'s reason', () async {
      final client = _clientWhoseAttempts(
        () => AtConnectionState.refused(
          AtConnectionCause.revoked,
          error: 'AT0027: enrollment_id is revoked',
        ),
      );
      await expectLater(
        onlineOrThrow(client, '@alice', const Duration(seconds: 15)),
        throwsA(
          isA<UnAuthenticatedException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('refused it (revoked)'),
              contains('AT0027: enrollment_id is revoked'),
            ),
          ),
        ),
      );
      verify(() => client.stop()).called(1);
    });

    test('still offline after the budget is a connectivity failure', () async {
      final client = _clientWhoseAttempts(
        () => AtConnectionState.offline(
          AtConnectionCause.unreachable,
          error: 'Connection refused',
        ),
      );
      await expectLater(
        onlineOrThrow(client, '@alice', const Duration(seconds: 1)),
        throwsA(
          isA<SecondaryServerConnectivityException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('within 1 seconds'),
              contains('offline (unreachable): Connection refused'),
            ),
          ),
        ),
      );
      verify(() => client.stop()).called(1);
    });
  });
}
