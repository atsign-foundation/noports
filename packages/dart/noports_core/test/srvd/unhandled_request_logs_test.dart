import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/session_crypto.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../harness/log_capture.dart';

class _MockAtClient extends Mock implements AtClient {}

/// An srvd whose atClient fails, which allocates no real ports.
class _FailingSrvd extends SrvdImpl {
  _FailingSrvd(AtClient atClient)
    : super(
        atClient: atClient,
        atSign: '@relay'.toAtsign(),
        homeDirectory: Directory.current.path,
        atKeysFilePath: Directory.current.path,
        managerAtsign: 'open',
        ipAddress: '127.0.0.1',
        logTraffic: false,
        verbose: false,
        bind443: false,
        localBindPort443: 443,
        relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
        signingKeyCheckInterval: Duration.zero,
      );

  @override
  Future<(PortPair, Isolate, SendPort)> spawnNewPortPairIsolate(
    SrvdSessionParams sessionParams,
  ) async {
    final port = ReceivePort();
    addTearDown(port.close);
    return ((1, 2), Isolate.current, port.sendPort);
  }
}

void main() {
  final capture = LogCapture.install();
  const alice = '@alice';

  group('Given srvd logging at every level', () {
    test('when handling a session request carrying a relay-auth key fails'
        ' unexpectedly, as when its atClient throws, then the log names the'
        ' request and its sender, and no log line contains the key', () async {
      final atClient = _MockAtClient();
      when(
        () => atClient.getCurrentAtSign(),
      ).thenThrow(StateError('the atClient has no atSign'));
      final srvd = _FailingSrvd(atClient)..logger.level = 'all';
      final key = generateAes256Key();

      await srvd.notificationHandler(
        AtNotification(
          Uuid().v4(),
          '@relay:device.request_ports.sshrvd$alice',
          alice,
          '@relay',
          DateTime.now().millisecondsSinceEpoch,
          'key',
          true,
          value: jsonEncode({
            'sessionId': Uuid().v4(),
            'atSignA': alice,
            'atSignB': '@bob',
            'clientNonce': 'client-nonce',
            'authenticateSocketA': true,
            'authenticateSocketB': true,
            'relayAuthMode': RelayAuthMode.escr.name,
            'relayAuthAesKey': key,
          }),
        ),
      );

      expect(
        recordsHoldingKey(capture.records, key),
        isEmpty,
        reason: 'no line srvd logs holds the relay-auth key',
      );
      expect(
        capture.records.map((r) => r.message),
        contains(
          allOf(
            contains('Exception'),
            contains('request_ports'),
            contains(alice),
          ),
        ),
        reason: 'the log names the request that failed and its sender',
      );
    });
  });
}
