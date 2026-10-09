import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srvd/isolates/shared_single_port_isolate.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../sshnp/sshnp_mocks.dart';

class FakeNotificationParams extends Fake implements NotificationParams {}

class FakeAtKey extends Fake implements AtKey {}

SrvdSessionParams params443({
  required String sessionId,
  RelayAuthMode relayAuthMode = RelayAuthMode.escr,
  bool authenticateSocketA = true,
  bool authenticateSocketB = true,
}) =>
    SrvdSessionParams(
      sessionId: sessionId,
      atSignA: '@alice',
      atSignB: '@bob',
      authenticateSocketA: authenticateSocketA,
      authenticateSocketB: authenticateSocketB,
      rvdNonce: 'rvd nonce',
      relayAuthMode: relayAuthMode,
      only443: true,
      multipleAcksOk: true,
      preFetch: const [],
      sendJsonResponse: true,
    );

void main() {
  group('SinglePortWorker.startSession', () {
    late ReceivePort toMain;
    late SinglePortWorker worker;
    late List<IIRequest> sentToMain;

    setUp(() {
      toMain = ReceivePort();
      sentToMain = [];
      toMain.listen((m) {
        if (m is IIRequest) sentToMain.add(m);
      });
      worker = SinglePortWorker(
        toMain: toMain.sendPort,
        logTraffic: false,
        verbose: false,
        loggingTag: 'single port refused start test',
        address: '127.0.0.1',
        useTLS: false,
        bindPort: 0,
      );
    });

    tearDown(() {
      for (final si in worker.sessions.values) {
        si.connector?.close();
      }
      worker.fromMain.close();
      toMain.close();
    });

    Future<List<IIRequest>> refusalsFor(SrvdSessionParams params) async {
      await worker.startSession(IIRequest.create('start', params));
      await pumpEventQueue();
      return sentToMain.where((m) => m.type == 'startRefused').toList();
    }

    test('tells main when it refuses a payload-mode session', () async {
      final id = Uuid().v4();
      final refusals = await refusalsFor(
        params443(sessionId: id, relayAuthMode: RelayAuthMode.payload),
      );
      expect(refusals, hasLength(1));
      expect(refusals.single.payload['sessionId'], id);
      expect(worker.sessions, isEmpty);
    });

    test('tells main when it refuses a session without both auth flags',
        () async {
      final id = Uuid().v4();
      final refusals = await refusalsFor(
        params443(sessionId: id, authenticateSocketB: false),
      );
      expect(refusals, hasLength(1));
      expect(refusals.single.payload['sessionId'], id);
      expect(worker.sessions, isEmpty);
    });

    test('says nothing to main about a session it starts', () async {
      final id = Uuid().v4();
      expect(await refusalsFor(params443(sessionId: id)), isEmpty);
      expect(worker.sessions.keys, [id]);
    });
  });

  group('SrvdImpl with a single-port isolate', () {
    late MockAtClient atClient;
    late MockNotificationService notificationService;
    late List<NotificationParams> notified;
    late SrvdImpl srvd;

    setUpAll(() {
      registerFallbackValue(FakeNotificationParams());
      registerFallbackValue(FakeAtKey());
    });

    setUp(() async {
      atClient = MockAtClient();
      notificationService = MockNotificationService();
      notified = [];
      when(() => atClient.getCurrentAtSign()).thenReturn('@relay');
      when(() => atClient.notificationService).thenReturn(notificationService);
      when(() => atClient.get(any())).thenAnswer(
        (_) async => AtValue()..value = 'a public key',
      );
      when(
        () => atClient.put(
          any(),
          any(),
          putRequestOptions: any(named: 'putRequestOptions'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => notificationService.notify(
          any(),
          checkForFinalDeliveryStatus: any(
            named: 'checkForFinalDeliveryStatus',
          ),
          waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
          onSentToSecondary: any(named: 'onSentToSecondary'),
        ),
      ).thenAnswer((i) async {
        notified.add(i.positionalArguments[0]);
        return NotificationResult()
          ..notificationStatusEnum = NotificationStatusEnum.delivered;
      });
      srvd = SrvdImpl(
        atClient: atClient,
        atSign: '@relay'.toAtsign(),
        homeDirectory: Directory.current.path,
        atKeysFilePath: Directory.current.path,
        managerAtsign: 'open',
        ipAddress: '127.0.0.1',
        logTraffic: false,
        verbose: false,
        bind443: true,
        localBindPort443: 0,
        relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
        signingKeyCheckInterval: Duration.zero,
      );
      await srvd.init();
    });

    tearDown(() {
      srvd.isolate443?.kill(priority: Isolate.immediate);
    });

    AtNotification requestPorts(
      String sessionId, {
      RelayAuthMode relayAuthMode = RelayAuthMode.escr,
      bool authenticateSocketB = true,
      bool multipleAcksOk = true,
    }) =>
        AtNotification(
          'notif-id',
          '@relay:device.request_ports.sshrvd@alice',
          '@alice',
          '@relay',
          DateTime.now().millisecondsSinceEpoch,
          'key',
          true,
          value: jsonEncode({
            'sessionId': sessionId,
            'atSignA': '@alice',
            'atSignB': '@bob',
            'clientNonce': 'client nonce',
            'authenticateSocketA': true,
            'authenticateSocketB': authenticateSocketB,
            'relayAuthMode': relayAuthMode.name,
            'only443': true,
            'multipleAcksOk': multipleAcksOk,
          }),
        );

    bool nacked(String sessionId) =>
        notified.any((n) => n.atKey.key == 'nack.$sessionId');

    bool answered(String sessionId) =>
        notified.any((n) => n.atKey.key == sessionId);

    test('refuses a payload-mode request without recording it', () async {
      final id = Uuid().v4();
      await srvd.handleRequestPorts(
        requestPorts(id, relayAuthMode: RelayAuthMode.payload),
      );
      await pumpEventQueue();
      expect(srvd.sessions.containsKey(id), isFalse);
      expect(nacked(id), isTrue);
      expect(answered(id), isFalse);
    });

    test('refuses a request without both auth flags without recording it',
        () async {
      final id = Uuid().v4();
      await srvd.handleRequestPorts(
        requestPorts(id, authenticateSocketB: false),
      );
      await pumpEventQueue();
      expect(srvd.sessions.containsKey(id), isFalse);
      expect(nacked(id), isTrue);
      expect(answered(id), isFalse);
    });

    test('refuses without a NACK a client that cannot take several acks',
        () async {
      final id = Uuid().v4();
      await srvd.handleRequestPorts(
        requestPorts(
          id,
          relayAuthMode: RelayAuthMode.payload,
          multipleAcksOk: false,
        ),
      );
      await pumpEventQueue();
      expect(srvd.sessions.containsKey(id), isFalse);
      expect(nacked(id), isFalse);
      expect(answered(id), isFalse);
    });

    test('records an ESCR request with both auth flags', () async {
      final id = Uuid().v4();
      await srvd.handleRequestPorts(requestPorts(id));
      await pumpEventQueue();
      expect(srvd.sessions.containsKey(id), isTrue);
      expect(nacked(id), isFalse);
      expect(answered(id), isTrue);
    });

    test('forgets a session the single-port isolate refuses to start',
        () async {
      final refused = Uuid().v4();
      final started = Uuid().v4();
      for (final (id, mode) in [
        (refused, RelayAuthMode.payload),
        (started, RelayAuthMode.escr),
      ]) {
        final p = params443(sessionId: id, relayAuthMode: mode);
        srvd.sessions[id] = SessionInfo(params: p, connector: null);
        srvd.toIsolate443!.send(IIRequest.create('start', p));
      }
      final deadline = DateTime.now().add(Duration(seconds: 5));
      while (srvd.sessions.containsKey(refused) &&
          DateTime.now().isBefore(deadline)) {
        await Future.delayed(Duration(milliseconds: 10));
      }
      expect(srvd.sessions.containsKey(refused), isFalse);
      expect(
        srvd.sessions.containsKey(started),
        isTrue,
        reason: 'a session the isolate starts stays recorded',
      );
    });
  });
}
