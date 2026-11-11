import 'package:at_client/at_client.dart' show InvalidAtSignException;
import 'package:noports_core/src/common/session_crypto.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group("Given a session's srvd params carrying a relay-auth key,", () {
    test('when they are printed, then the text names the session and its'
        ' atSigns, and holds none of the key.', () {
      final sessionId = Uuid().v4();
      final key = generateAes256Key();
      final params = SrvdSessionParams(
        sessionId: sessionId,
        atSignA: '@alice',
        atSignB: '@bob',
        authenticateSocketA: true,
        authenticateSocketB: true,
        rvdNonce: 'rvd-nonce',
        relayAuthMode: RelayAuthMode.escr,
        relayAuthAesKey: key,
        only443: false,
        multipleAcksOk: true,
        preFetch: [],
        sendJsonResponse: true,
      );

      final text = '$params';

      final half = key.length ~/ 2;
      expect(
        [key.substring(0, half), key.substring(half)].where(text.contains),
        isEmpty,
        reason: 'the text holds no part of the relay-auth key',
      );
      expect(
        text,
        allOf(contains(sessionId), contains('@alice'), contains('@bob')),
      );
      expect(params.relayAuthAesKey, key, reason: 'the params keep the key');
    });
  });

  group("Given a session's client-side and device-side Atsigns,", () {
    SrvdSessionParams between(String a, String b) => SrvdSessionParams(
          sessionId: 'the-session',
          atSignA: a,
          atSignB: b,
          rvdNonce: 'rvd-nonce',
          only443: false,
          multipleAcksOk: true,
          preFetch: const [],
          sendJsonResponse: true,
        );

    test('when they are valid, then the params hold them canonical', () {
      final params = between('Alice', '@B.ob');

      expect(params.atSignA, '@alice');
      expect(params.atSignB, '@bob');
    });

    test('when either is not a valid Atsign, then no params are made', () {
      expect(between('@alice', '@bob').atSignB, '@bob',
          reason: 'the control: two valid Atsigns make params');
      for (final (String a, String b) in [
        ('@a@b', '@bob'),
        ('@alice', '@a@b'),
        ('@alice', '@${'d' * 56}'),
      ]) {
        expect(() => between(a, b), throwsA(isA<InvalidAtSignException>()),
            reason: '$a and $b make no params');
      }
    });
  });
}
