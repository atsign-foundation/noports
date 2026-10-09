import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

class FakeAtKey extends Fake implements AtKey {}

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

  group('Given srvd', () {
    setUpAll(() => registerFallbackValue(FakeAtKey()));

    AtNotification payloadRequest({
      required String from,
      required String atSignA,
      String sessionId = 'the session',
    }) =>
        AtNotification(
          'notif-id',
          '@relay:device.request_ports.sshrvd$from',
          from,
          '@relay',
          DateTime.now().millisecondsSinceEpoch,
          'key',
          true,
          value: jsonEncode({
            'sessionId': sessionId,
            'atSignA': atSignA,
            'atSignB': '@device',
            'clientNonce': 'client nonce',
            'authenticateSocketA': true,
            'authenticateSocketB': true,
            'relayAuthMode': RelayAuthMode.payload.name,
          }),
        );

    RecordingSrvd srvdAnsweringLookups({required String managerAtsign}) {
      final srvd = RecordingSrvd(managerAtsign: managerAtsign);
      when(() => (srvd.atClient as MockAtClient).get(any())).thenAnswer(
        (_) async => AtValue()..value = 'a public key',
      );
      return srvd;
    }

    test(
        "when a session request it will deny arrives (from a sender who "
        "isn't the request's atSignA, from someone other than the manager "
        'on a managed relay, or for a session id already live), then srvd '
        "denies it without looking up either side's public key", () async {
      final notAtSignA = srvdAnsweringLookups(managerAtsign: 'open');
      await notAtSignA.handleRequestPorts(
        payloadRequest(from: '@mallory', atSignA: '@alice'),
      );

      final notManager = srvdAnsweringLookups(managerAtsign: '@manager');
      await notManager.handleRequestPorts(
        payloadRequest(from: '@mallory', atSignA: '@mallory'),
      );

      final liveId = srvdAnsweringLookups(managerAtsign: 'open');
      liveId.sessions['the session'] = SessionInfo(
        params: SrvdSessionParams(
          sessionId: 'the session',
          atSignA: '@bob',
          atSignB: '@device',
          rvdNonce: 'rvd nonce',
          only443: false,
          multipleAcksOk: true,
          preFetch: const [],
          sendJsonResponse: true,
        ),
        connector: null,
      );
      await liveId.handleRequestPorts(
        payloadRequest(from: '@alice', atSignA: '@alice'),
      );

      for (final srvd in [notAtSignA, notManager, liveId]) {
        expect(srvd.allocated, isFalse);
        verifyNever(() => (srvd.atClient as MockAtClient).get(any()));
      }

      final accepted = srvdAnsweringLookups(managerAtsign: 'open');
      await accepted.handleRequestPorts(
        payloadRequest(from: '@alice', atSignA: '@alice'),
      );
      expect(accepted.allocated, isTrue);
      verify(() => (accepted.atClient as MockAtClient).get(any())).called(2);
    });
  });
}
