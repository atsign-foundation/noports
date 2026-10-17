/// Goal: no relay-auth key, socket key or IV, or request content reaches a
/// log record. Non-goals: hiding other error detail, which is logged in full,
/// and sanitising a third-party component's own error text.
library;

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
}
