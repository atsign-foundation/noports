import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

void main() {
  group('SrvdImpl.handleAuthModes', () {
    const clientAtsign = '@alice';
    const daemonAtsign = '@bob';
    const relayAtSign = '@relay';
    const sessionId = 'sess-123';

    // The rvdNonce THIS relay instance generated for the session.
    const relayRvdNonce = '2026-01-01T00:00:00.000001';

    late SrvdImpl srvd;
    late ReceivePort workerPort;
    late List<dynamic> forwarded;

    SrvdImpl makeSrvd() => SrvdImpl(
      atClient: MockAtClient(),
      atSign: relayAtSign.toAtsign(),
      homeDirectory: Directory.current.path,
      atKeysFilePath: Directory.current.path,
      managerAtsign: 'open',
      ipAddress: '127.0.0.1',
      logTraffic: false,
      verbose: false,
      bind443: false,
      localBindPort443: 443,
      relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
    );

    /// Registers a session owned by this relay instance, wiring [toWorker] to a
    /// [ReceivePort] we can inspect. [rvdNonce] is the nonce this instance
    /// generated; [toWorker] null models the only443 path (no worker isolate).
    void registerSession({
      String rvdNonce = relayRvdNonce,
      bool withWorker = true,
    }) {
      srvd.sessions[sessionId] = SessionInfo(
        params: SrvdSessionParams(
          sessionId: sessionId,
          atSignA: clientAtsign,
          atSignB: daemonAtsign,
          authenticateSocketA: true,
          authenticateSocketB: true,
          rvdNonce: rvdNonce,
          only443: false,
          multipleAcksOk: true,
          preFetch: const [],
          sendJsonResponse: true,
        ),
        connector: null,
        toWorker: withWorker ? workerPort.sendPort : null,
      );
    }

    AtNotification authModes({
      String from = clientAtsign,
      String? value,
      String rvdNonce = relayRvdNonce,
      String sideA = 'escr',
      String sideB = 'escr',
      String sid = sessionId,
    }) {
      final v =
          value ??
          jsonEncode({
            'sessionId': sid,
            'rvdNonce': rvdNonce,
            'sideA': sideA,
            'sideB': sideB,
          });
      return AtNotification(
        'notif-id',
        '$relayAtSign:local.auth_modes.sshrvd$from',
        from,
        relayAtSign,
        123,
        'key',
        true,
      )..value = v;
    }

    /// Runs [handleAuthModes] and gives the port a moment to deliver.
    Future<void> deliver(AtNotification n) async {
      await srvd.handleAuthModes(n);
      await Future.delayed(const Duration(milliseconds: 20));
    }

    setUp(() {
      srvd = makeSrvd();
      workerPort = ReceivePort();
      forwarded = [];
      workerPort.listen(forwarded.add);
    });

    tearDown(() => workerPort.close());

    test('forwards to the worker when sender and rvdNonce match', () async {
      registerSession();
      await deliver(authModes(sideA: 'escr', sideB: 'payload'));

      expect(forwarded, hasLength(1));
      final req = forwarded.single as IIRequest;
      expect(req.type, 'auth_modes');
      expect(req.payload['sideA'], 'escr');
      expect(req.payload['sideB'], 'payload');
    });

    test('ignores a notification whose rvdNonce is another instance\'s',
        () async {
      // Several relays share @relay; this instance generated relayRvdNonce, but
      // the client accepted a different instance's response, so its
      // notification carries that other instance's nonce.
      registerSession(rvdNonce: relayRvdNonce);
      await deliver(authModes(rvdNonce: 'a-different-instances-nonce'));

      expect(forwarded, isEmpty);
    });

    test('ignores a notification from someone other than the requester',
        () async {
      registerSession();
      await deliver(authModes(from: daemonAtsign)); // not atSignA

      expect(forwarded, isEmpty);
    });

    test('ignores a notification for a session this relay does not know',
        () async {
      // no registerSession()
      await deliver(authModes());

      expect(forwarded, isEmpty);
    });

    test('ignores a malformed (non-JSON) value', () async {
      registerSession();
      await deliver(authModes(value: 'not json'));

      expect(forwarded, isEmpty);
    });

    test('ignores a value with no sessionId', () async {
      registerSession();
      await deliver(authModes(value: jsonEncode({'sideA': 'escr'})));

      expect(forwarded, isEmpty);
    });

    test('does not throw when the session has no worker (only443 path)',
        () async {
      registerSession(withWorker: false);
      // Should simply no-op rather than blow up.
      await deliver(authModes());

      expect(forwarded, isEmpty);
    });
  });
}
