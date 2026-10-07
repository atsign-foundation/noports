import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

/// Records whether a request got as far as allocating ports, then stops it,
/// once [gate] (when given) completes.
class RecordingSrvd extends SrvdImpl {
  RecordingSrvd({required super.managerAtsign, this.gate})
      : super(
          atClient: MockAtClient(),
          atSign: '@relay'.toAtsign(),
          homeDirectory: Directory.current.path,
          atKeysFilePath: Directory.current.path,
          ipAddress: '127.0.0.1',
          logTraffic: false,
          verbose: false,
          bind443: false,
          localBindPort443: 443,
          relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
          signingKeyCheckInterval: Duration.zero,
        );

  final Future<void>? gate;

  int allocations = 0;

  bool get allocated => allocations > 0;

  @override
  Future<(PortPair, Isolate, SendPort)> spawnNewPortPairIsolate(
    SrvdSessionParams sessionParams,
  ) async {
    allocations++;
    await gate;
    throw StateError('stopped after the gate');
  }
}

void main() {
  group('SrvdImpl.handleRequestPorts', () {
    AtNotification requestPorts({required String from, required String atSignA}) =>
        AtNotification(
          'notif-id',
          '@relay:device.request_ports.sshrvd$from',
          from,
          '@relay',
          DateTime.now().millisecondsSinceEpoch,
          'key',
          true,
          value: jsonEncode({
            'sessionId': 'the session',
            'atSignA': atSignA,
            'atSignB': '@device',
            'clientNonce': 'client nonce',
            'authenticateSocketA': false,
            'authenticateSocketB': false,
            'relayAuthMode': RelayAuthMode.escr.name,
          }),
        );

    Future<bool> allocates({
      required String manager,
      required String from,
      required String atSignA,
    }) async {
      final srvd = RecordingSrvd(managerAtsign: manager);
      await srvd.handleRequestPorts(requestPorts(from: from, atSignA: atSignA));
      return srvd.allocated;
    }

    test('lets the manager through', () async {
      expect(
        await allocates(manager: '@manager', from: '@manager', atSignA: '@manager'),
        isTrue,
      );
    });

    test('refuses a sender that is not the manager', () async {
      expect(
        await allocates(manager: '@manager', from: '@mallory', atSignA: '@mallory'),
        isFalse,
      );
    });

    test('refuses a sender naming the manager as atSignA', () async {
      expect(
        await allocates(manager: '@manager', from: '@mallory', atSignA: '@manager'),
        isFalse,
      );
    });

    test('refuses a sender naming another atSign on an open relay', () async {
      expect(
        await allocates(manager: 'open', from: '@mallory', atSignA: '@alice'),
        isFalse,
      );
    });

    test('compares the sender with the normalised atSignA', () async {
      expect(
        await allocates(manager: 'open', from: '@alice', atSignA: '@Alice'),
        isTrue,
      );
    });

    test('refuses a session id that is already live', () async {
      expect(
        await allocates(manager: 'open', from: '@mallory', atSignA: '@mallory'),
        isTrue,
        reason: 'the same request is let through when no session is live',
      );
      final srvd = RecordingSrvd(managerAtsign: 'open');
      final live = SessionInfo(
        params: SrvdSessionParams(
          sessionId: 'the session',
          atSignA: '@alice',
          atSignB: '@device',
          rvdNonce: 'rvd nonce',
          only443: false,
          multipleAcksOk: true,
          preFetch: const [],
          sendJsonResponse: true,
        ),
        connector: null,
      );
      srvd.sessions['the session'] = live;

      await srvd.handleRequestPorts(
        requestPorts(from: '@mallory', atSignA: '@mallory'),
      );

      expect(srvd.allocated, isFalse);
      expect(srvd.sessions['the session'], same(live));
    });

    test('refuses a session id that is still being started', () async {
      final gate = Completer<void>();
      final srvd = RecordingSrvd(managerAtsign: 'open', gate: gate.future);
      final first = srvd.handleRequestPorts(
        requestPorts(from: '@alice', atSignA: '@alice'),
      );
      await pumpEventQueue();
      expect(srvd.allocations, 1, reason: 'the first request is mid-start');

      final second = srvd.handleRequestPorts(
        requestPorts(from: '@mallory', atSignA: '@mallory'),
      );
      await pumpEventQueue();
      expect(srvd.allocations, 1);

      gate.complete();
      await Future.wait([first, second]);
      await srvd.handleRequestPorts(
        requestPorts(from: '@mallory', atSignA: '@mallory'),
      );
      expect(srvd.allocations, 2, reason: 'a start that failed frees its id');
    });
  });
}
