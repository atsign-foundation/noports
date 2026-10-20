import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/sshnp/impl/notification_request_message.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

const _invalidSessionIds = [
  '',
  'ssh',
  'abc\nssh-ed25519 AAAAattackerKey attacker',
  '6ba7b810-9dad-11d1-80b4-00c04fd430c8\n',
  '../../tmp/x',
];

final _throwsSessionIdError = throwsA(
  isA<ArgumentError>().having((e) => e.name, 'name', 'sessionId'),
);

void main() {
  group('SshnpSessionRequest.fromJson', () {
    late Map<String, dynamic> validJson;

    setUp(() {
      validJson = SshnpSessionRequest(
        direct: true,
        sessionId: Uuid().v4(),
        host: '127.0.0.1',
        port: 9000,
        relayAuthMode: RelayAuthMode.payload,
        relayAuthAesKey: null,
        twinKeys: false,
        relayAtsign: null,
      ).toJson();
    });

    test('accepts a UUID sessionId', () {
      final req = SshnpSessionRequest.fromJson(validJson);
      expect(req.sessionId, validJson['sessionId']);
    });

    test('refuses a sessionId which is not a UUID', () {
      for (final sessionId in _invalidSessionIds) {
        expect(
          () => SshnpSessionRequest.fromJson({
            ...validJson,
            'sessionId': sessionId,
          }),
          _throwsSessionIdError,
          reason: 'accepted "$sessionId"',
        );
      }
    });
  });

  group('NptSessionRequest.fromJson', () {
    late Map<String, dynamic> validJson;

    setUp(() {
      validJson = NptSessionRequest(
        sessionId: Uuid().v4(),
        rvdHost: '127.0.0.1',
        rvdPort: 9000,
        requestedHost: 'localhost',
        requestedPort: 3389,
        authenticateToRvd: true,
        relayAuthMode: RelayAuthMode.payload,
        relayAuthAesKey: null,
        clientNonce: 'clientNonce',
        rvdNonce: 'rvdNonce',
        encryptRvdTraffic: true,
        clientEphemeralPK: 'clientEphemeralPK',
        clientEphemeralPKType: 'rsa2048',
        timeout: const Duration(seconds: 30),
        twinKeys: false,
        relayAtsign: null,
      ).toJson();
    });

    test('accepts a UUID sessionId', () {
      final req = NptSessionRequest.fromJson(validJson);
      expect(req.sessionId, validJson['sessionId']);
    });

    test('refuses a sessionId which is not a UUID', () {
      for (final sessionId in _invalidSessionIds) {
        expect(
          () => NptSessionRequest.fromJson({
            ...validJson,
            'sessionId': sessionId,
          }),
          _throwsSessionIdError,
          reason: 'accepted "$sessionId"',
        );
      }
    });
  });
}
