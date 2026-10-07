import 'dart:isolate';

import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srvd/isolates/port_pair_isolate.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

void main() {
  test('createAuthVerifiers guards side A for atSignA and side B for atSignB',
      () async {
    final toMain = ReceivePort();
    final worker = PortPairWorker(
      toMain: toMain.sendPort,
      logTraffic: false,
      verbose: false,
      loggingTag: 'relay worker test',
      relayAuthDetectWindowMs: 500,
    );
    addTearDown(() {
      worker.fromMain.close();
      toMain.close();
    });

    final (a, b) = await worker.createAuthVerifiers(SrvdSessionParams(
      sessionId: 'the session',
      atSignA: '@alice',
      atSignB: '@bob',
      authenticateSocketA: true,
      authenticateSocketB: true,
      rvdNonce: 'rvd nonce',
      relayAuthMode: RelayAuthMode.escr,
      relayAuthAesKey: 'relay auth key',
      only443: false,
      multipleAcksOk: true,
      preFetch: [],
      sendJsonResponse: true,
    ));

    expect((a!.isSideA, a.atSign, a.sessionId), (true, '@alice', 'the session'));
    expect((b!.isSideA, b.atSign, b.sessionId), (false, '@bob', 'the session'));
  });
}
