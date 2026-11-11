import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:logging/logging.dart';
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

class FakeNotificationParams extends Fake implements NotificationParams {}

/// An srvd whose port pairs come from nowhere, so a request it accepts gets
/// as far as being recorded as a session and answered.
class AnsweringSrvd extends SrvdImpl {
  AnsweringSrvd({required super.atClient, required super.managerAtsign})
      : super(
          atSign: '@relay'.toAtsign(),
          homeDirectory: Directory.current.path,
          atKeysFilePath: Directory.current.path,
          ipAddress: '127.0.0.1',
          logTraffic: false,
          verbose: false,
          bind443: false,
          localBindPort443: 0,
          relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
          signingKeyCheckInterval: Duration.zero,
        );

  final ReceivePort portPair = ReceivePort();

  @override
  Future<(PortPair, Isolate, SendPort)> spawnNewPortPairIsolate(
    SrvdSessionParams sessionParams,
  ) async =>
      ((40001, 40002), Isolate.current, portPair.sendPort);
}

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
        await allocates(manager: '@manager', from: '@carol', atSignA: '@carol'),
        isFalse,
      );
    });

    test('refuses a sender naming the manager as atSignA', () async {
      expect(
        await allocates(manager: '@manager', from: '@carol', atSignA: '@manager'),
        isFalse,
      );
    });

    test('refuses a sender naming another atSign on an open relay', () async {
      expect(
        await allocates(manager: 'open', from: '@carol', atSignA: '@alice'),
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
        await allocates(manager: 'open', from: '@carol', atSignA: '@carol'),
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
        requestPorts(from: '@carol', atSignA: '@carol'),
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
        requestPorts(from: '@carol', atSignA: '@carol'),
      );
      await pumpEventQueue();
      expect(srvd.allocations, 1);

      gate.complete();
      await Future.wait([first, second]);
      await srvd.handleRequestPorts(
        requestPorts(from: '@carol', atSignA: '@carol'),
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
      when(() => (srvd.atClient as MockAtClient).get(any(), getRequestOptions: any(named: 'getRequestOptions'))).thenAnswer(
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
        payloadRequest(from: '@carol', atSignA: '@alice'),
      );

      final notManager = srvdAnsweringLookups(managerAtsign: '@manager');
      await notManager.handleRequestPorts(
        payloadRequest(from: '@carol', atSignA: '@carol'),
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
        verifyNever(() => (srvd.atClient as MockAtClient).get(any(), getRequestOptions: any(named: 'getRequestOptions')));
      }

      final accepted = srvdAnsweringLookups(managerAtsign: 'open');
      await accepted.handleRequestPorts(
        payloadRequest(from: '@alice', atSignA: '@alice'),
      );
      expect(accepted.allocated, isTrue);
      verify(() => (accepted.atClient as MockAtClient).get(any(), getRequestOptions: any(named: 'getRequestOptions'))).called(2);
    });

    test(
        'when two requests for the same session id arrive together and the '
        'first is still looking up its payload-mode keys, then srvd starts '
        'only the first', () async {
      final keysGate = Completer<void>();
      final srvd = RecordingSrvd(managerAtsign: 'open');
      when(() => (srvd.atClient as MockAtClient).get(any(), getRequestOptions: any(named: 'getRequestOptions'))).thenAnswer(
        (_) async {
          await keysGate.future;
          return AtValue()..value = 'a public key';
        },
      );

      final first = srvd.handleRequestPorts(
        payloadRequest(from: '@alice', atSignA: '@alice'),
      );
      final second = srvd.handleRequestPorts(
        payloadRequest(from: '@alice', atSignA: '@alice'),
      );
      await pumpEventQueue();
      expect(srvd.allocations, 0, reason: 'the first is still looking up');

      keysGate.complete();
      await Future.wait([first, second]);
      expect(srvd.allocations, 1);
    });
  });

  group("Given srvd answering session requests, the session's Atsigns", () {
    const String sessionId = '0f8fad5b-d9cb-469f-a165-70867728950e';
    late List<NotificationParams> sent;
    late List<String> logged;
    late List<String> shouts;

    setUpAll(() => registerFallbackValue(FakeNotificationParams()));

    Future<AnsweringSrvd> relay({
      String manager = 'open',
      bool notifyFails = false,
    }) async {
      sent = [];
      logged = [];
      shouts = [];
      final atClient = MockAtClient();
      final notificationService = MockNotificationService();
      when(() => atClient.notificationService).thenReturn(notificationService);
      when(
        () => notificationService.notify(
          any(),
          checkForFinalDeliveryStatus:
              any(named: 'checkForFinalDeliveryStatus'),
          waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
          onSentToSecondary: any(named: 'onSentToSecondary'),
        ),
      ).thenAnswer((i) async {
        sent.add(i.positionalArguments.first as NotificationParams);
        return notifyFails
            ? (NotificationResult()
              ..notificationStatusEnum = NotificationStatusEnum.undelivered
              ..atClientException = AtClientException.message('no route'))
            : (NotificationResult()
              ..notificationStatusEnum = NotificationStatusEnum.delivered);
      });
      final srvd = AnsweringSrvd(atClient: atClient, managerAtsign: manager);
      await srvd.init();
      srvd.logger.logger.onRecord.listen((r) {
        logged.add(r.message);
        if (r.level == Level.SHOUT) shouts.add(r.message);
      });
      addTearDown(srvd.portPair.close);
      return srvd;
    }

    Future<void> request(
      AnsweringSrvd srvd, {
      String from = '@alice',
      String atSignA = '@alice',
      String atSignB = '@bob',
      bool multipleAcksOk = false,
      String id = sessionId,
    }) async {
      await srvd.handleRequestPorts(AtNotification(
        'notif-id',
        '@relay:gateway-1.request_ports.sshrvd$from',
        from,
        '@relay',
        DateTime.now().millisecondsSinceEpoch,
        'key',
        true,
        value: jsonEncode({
          'sessionId': id,
          'atSignA': atSignA,
          'atSignB': atSignB,
          'clientNonce': 'client nonce',
          'authenticateSocketA': false,
          'authenticateSocketB': false,
          'relayAuthMode': RelayAuthMode.escr.name,
          'only443': false,
          'multipleAcksOk': multipleAcksOk,
        }),
      ));
      await pumpEventQueue();
    }

    Iterable<String> refusals() =>
        logged.where((m) => m.startsWith('Unable to provide the socket pair'));

    test('the control: a request naming two valid Atsigns is answered',
        () async {
      final srvd = await relay();

      await request(srvd, atSignB: '@Bob', multipleAcksOk: true);

      expect(srvd.sessions.keys, [sessionId]);
      expect(srvd.sessions[sessionId]!.atSignB, '@bob',
          reason: 'the session holds the device-side Atsign canonical');
      expect(sent, hasLength(1), reason: '@alice is sent its ports');
      expect(sent.single.atKey.key, isNot(startsWith('nack.')));
      expect(sent.single.atKey.sharedWith, '@alice');
      expect(refusals(), isEmpty);
    });

    test(
        'A session request whose device-side Atsign is not a valid Atsign is'
        ' refused', () async {
      final srvd = await relay();
      for (final (String atSignB, String why) in [
        ('@a@b', 'more than one @'),
        ('@${'d' * 56}', 'at most 55 characters'),
      ]) {
        logged.clear();

        await request(srvd, atSignB: atSignB);

        expect(srvd.sessions, isEmpty, reason: 'no session for $atSignB');
        expect(sent, isEmpty, reason: '@alice is sent no ports for $atSignB');
        expect(
          refusals().single,
          allOf(
            contains('for @alice'),
            contains('Parameter atSignB is not a valid Atsign'),
            contains(why),
          ),
          reason: 'the refusal names the sender, atSignB and why',
        );
      }
    });

    test(
        'A session request whose client-side Atsign is not a valid Atsign is'
        ' refused', () async {
      final srvd = await relay();

      await request(srvd, atSignA: '@a@b');

      expect(srvd.sessions, isEmpty);
      expect(sent, isEmpty, reason: '@alice is sent no ports');
      expect(
        refusals().single,
        allOf(
          contains('for @alice'),
          contains('Parameter atSignA is not a valid Atsign'),
          contains('more than one @'),
        ),
        reason: 'the refusal names the sender, atSignA and why',
      );
    });

    test(
        'A refused session request is sent a NACK saying why when its client'
        ' takes NACKs', () async {
      final srvd = await relay();

      await request(srvd,
          from: '@carol', atSignB: '@a@b', multipleAcksOk: true);

      expect(srvd.sessions, isEmpty);
      expect(sent, hasLength(1), reason: 'one NACK and no ports');
      final nack = sent.single;
      expect(nack.atKey.key, 'nack.$sessionId');
      expect(nack.atKey.sharedWith, '@carol',
          reason: 'the NACK goes to the sender, not the atSignA it named');
      expect(nack.value, contains('Parameter atSignB is not a valid Atsign'));
      expect(nack.value, contains('more than one @'));
    });

    test("A NACK that cannot be sent is logged at srvd's default level",
        () async {
      final srvd = await relay(notifyFails: true);

      await request(srvd,
          from: '@carol', atSignB: '@a@b', multipleAcksOk: true);

      expect(sent, hasLength(1), reason: 'srvd tried to send the NACK');
      expect(
        shouts.where((m) => m.contains('NACK for session $sessionId to @carol'
            ' was not sent: ')),
        hasLength(1),
        reason: 'srvd logs at shout unless it is verbose',
      );
    });

    test(
        'A refused session request whose session id is not a UUID is sent'
        ' nothing, and its id is not logged', () async {
      final srvd = await relay();

      await request(srvd,
          id: 'not\nSHOUT|a line', atSignB: '@a@b', multipleAcksOk: true);

      expect(sent, isEmpty, reason: 'no NACK under a key that is not a UUID');
      expect(refusals().single, contains('not a UUID'));
      expect(logged.where((m) => m.contains('SHOUT|a line')), isEmpty,
          reason: 'the id is not written to the log');
    });

    test(
        'On a relay with a manager, a session request from another Atsign is'
        ' refused before it is read, and sent nothing', () async {
      final srvd = await relay(manager: '@manager');

      await request(srvd,
          from: '@manager', atSignA: '@manager', multipleAcksOk: true);
      expect(sent, hasLength(1),
          reason: "the control: the manager's request is answered");
      sent.clear();

      await request(srvd,
          from: '@carol',
          atSignA: '@carol',
          atSignB: '@a@b',
          multipleAcksOk: true,
          id: 'a6b0b47c-1c2a-4f4b-9b77-2d0f3f1f5a10');

      expect(sent, isEmpty, reason: '@carol is sent no NACK');
      expect(refusals(), isEmpty, reason: "@carol's request is not read");
      expect(
        logged.where((m) => m.contains('only the manager may request')),
        hasLength(1),
      );
    });
  });
}
