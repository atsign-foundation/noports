import 'dart:isolate';

import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srvd/isolates/shared_single_port_isolate.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

void main() {
  test('stop() closes the connector of every session it is relaying',
      () async {
    final toMain = ReceivePort();
    final worker = SinglePortWorker(
      toMain: toMain.sendPort,
      logTraffic: false,
      verbose: false,
      loggingTag: 'single port stop test',
      address: '127.0.0.1',
      useTLS: false,
      bindPort: 0,
    );
    addTearDown(() {
      worker.fromMain.close();
      toMain.close();
    });
    for (final sessionId in ['session one', 'session two']) {
      await worker.startSession(IIRequest.create(
        'start',
        SrvdSessionParams(
          sessionId: sessionId,
          atSignA: '@alice',
          atSignB: '@bob',
          authenticateSocketA: true,
          authenticateSocketB: true,
          rvdNonce: 'rvd nonce',
          relayAuthMode: RelayAuthMode.escr,
          relayAuthAesKey: 'relay auth key',
          only443: true,
          multipleAcksOk: true,
          preFetch: [],
          sendJsonResponse: true,
        ),
      ));
    }
    final connectors = [
      for (final si in worker.sessions.values) si.connector!,
    ];
    expect(connectors, hasLength(2));
    expect(connectors.where((c) => c.closed), isEmpty);

    await worker.stop();

    expect(connectors.where((c) => !c.closed), isEmpty);
  });
}
