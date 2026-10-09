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
  bool only443 = true,
}) =>
    SrvdSessionParams(
      sessionId: sessionId,
      atSignA: '@alice',
      atSignB: '@bob',
      authenticateSocketA: authenticateSocketA,
      authenticateSocketB: authenticateSocketB,
      rvdNonce: 'rvd nonce',
      relayAuthMode: relayAuthMode,
      only443: only443,
      multipleAcksOk: true,
      preFetch: const [],
      sendJsonResponse: true,
    );

void main() {
  late ReceivePort toMain;
  late SinglePortWorker worker;
  late List<IIRequest> sentToMain;

  void setUpWorker() {
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
  }

  void tearDownWorker() {
    for (final si in worker.sessions.values) {
      si.connector?.close();
    }
    worker.fromMain.close();
    toMain.close();
  }

  Future<List<IIRequest>> refusalsAfterStart(SrvdSessionParams params) async {
    await worker.startSession(IIRequest.create('start', params));
    await pumpEventQueue();
    return sentToMain.where((m) => m.type == 'startRefused').toList();
  }

  group('Given a single-port isolate', () {
    setUp(setUpWorker);
    tearDown(tearDownWorker);

    test(
        'when a start in payload mode arrives, then it tells main '
        'startRefused and starts nothing', () async {
      final id = Uuid().v4();
      final refusals = await refusalsAfterStart(
        params443(sessionId: id, relayAuthMode: RelayAuthMode.payload),
      );
      expect(refusals, hasLength(1));
      expect(refusals.single.payload['sessionId'], id);
      expect(worker.sessions, isEmpty);
    });

    test(
        "when a start where a side won't authenticate arrives, then it "
        'tells main startRefused and starts nothing', () async {
      final id = Uuid().v4();
      final refusals = await refusalsAfterStart(
        params443(sessionId: id, authenticateSocketB: false),
      );
      expect(refusals, hasLength(1));
      expect(refusals.single.payload['sessionId'], id);
      expect(worker.sessions, isEmpty);
    });

    test(
        'when a start with ESCR and both sides authenticating arrives, then '
        'it starts the session and tells main nothing', () async {
      final id = Uuid().v4();
      expect(await refusalsAfterStart(params443(sessionId: id)), isEmpty);
      expect(worker.sessions.keys, [id]);
    });
  });

  group('Given a single-port isolate with a live session X', () {
    setUp(setUpWorker);
    tearDown(tearDownWorker);

    test(
        'when a start for X arrives with params it would refuse, then it '
        'tells main nothing and X stays live', () async {
      final x = Uuid().v4();
      expect(await refusalsAfterStart(params443(sessionId: x)), isEmpty);
      final live = worker.sessions[x];
      expect(live, isNotNull);

      final refusals = await refusalsAfterStart(
        params443(sessionId: x, relayAuthMode: RelayAuthMode.payload),
      );
      expect(refusals, isEmpty);
      expect(worker.sessions[x], same(live));
    });
  });

  group('Given srvd bound to port 443', () {
    late MockAtClient atClient;
    late MockNotificationService notificationService;
    late List<NotificationParams> notified;
    late SrvdImpl srvd;
    late ReceivePort isolateRecorder;
    late List<IIRequest> sentToIsolate;

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
      isolateRecorder = ReceivePort();
      sentToIsolate = [];
      isolateRecorder.listen((m) {
        if (m is IIRequest) sentToIsolate.add(m);
      });
    });

    tearDown(() {
      isolateRecorder.close();
      srvd.isolate443?.kill(priority: Isolate.immediate);
    });

    /// Swaps srvd's channel to its single-port isolate for one that records
    /// what srvd sends it.
    void recordWhatTheIsolateIsSent() {
      srvd.toIsolate443 = isolateRecorder.sendPort;
    }

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

    bool startSent(String sessionId) => sentToIsolate.any(
        (m) => m.type == 'start' && m.payload.sessionId == sessionId);

    void verifyNoMutex() => verifyNever(
          () => atClient.put(
            any(),
            any(),
            putRequestOptions: any(named: 'putRequestOptions'),
          ),
        );

    Future<void> expectRefusedWithNack(AtNotification request) async {
      recordWhatTheIsolateIsSent();
      final id = jsonDecode(request.value!)['sessionId'];
      await srvd.handleRequestPorts(request);
      await pumpEventQueue();
      expect(nacked(id), isTrue);
      expect(startSent(id), isFalse);
      verifyNoMutex();
      expect(srvd.sessions.containsKey(id), isFalse);
      expect(answered(id), isFalse);

      final control = Uuid().v4();
      await srvd.handleRequestPorts(requestPorts(control));
      await pumpEventQueue();
      expect(
        startSent(control),
        isTrue,
        reason: 'control: the recorder sees the start of a session srvd '
            'accepts',
      );
    }

    test(
        'when a port 443 request in payload mode arrives from a client that '
        'takes several acks, then srvd NACKs it, sends the isolate nothing, '
        'takes no session mutex and records no session', () async {
      await expectRefusedWithNack(
        requestPorts(Uuid().v4(), relayAuthMode: RelayAuthMode.payload),
      );
    });

    test(
        "when a port 443 request where a side won't authenticate arrives "
        'from a client that takes several acks, then srvd NACKs it, sends '
        'the isolate nothing, takes no session mutex and records no session',
        () async {
      await expectRefusedWithNack(
        requestPorts(Uuid().v4(), authenticateSocketB: false),
      );
    });

    test(
        'when a port 443 request in payload mode arrives with both auth '
        "flags set, then srvd NACKs it without looking up either side's "
        'public key', () async {
      final id = Uuid().v4();
      await srvd.handleRequestPorts(
        requestPorts(id, relayAuthMode: RelayAuthMode.payload),
      );
      await pumpEventQueue();
      expect(nacked(id), isTrue);
      verifyNever(() => atClient.get(any()));

      await srvd.withPayloadKeys(
        params443(
          sessionId: Uuid().v4(),
          relayAuthMode: RelayAuthMode.payload,
          only443: false,
        ),
      );
      verify(() => atClient.get(any())).called(2);
    });

    test(
        'when a refused port 443 request arrives from a client that takes '
        'one ack, then srvd refuses it without a NACK', () async {
      recordWhatTheIsolateIsSent();
      final id = Uuid().v4();
      await srvd.handleRequestPorts(
        requestPorts(
          id,
          relayAuthMode: RelayAuthMode.payload,
          multipleAcksOk: false,
        ),
      );
      await pumpEventQueue();
      expect(nacked(id), isFalse);
      expect(startSent(id), isFalse);
      verifyNoMutex();
      expect(srvd.sessions.containsKey(id), isFalse);
      expect(answered(id), isFalse);

      final control = Uuid().v4();
      await srvd.handleRequestPorts(
        requestPorts(control, multipleAcksOk: false),
      );
      await pumpEventQueue();
      verify(
        () => atClient.put(
          any(),
          any(),
          putRequestOptions: any(named: 'putRequestOptions'),
        ),
      ).called(1);
    });

    test(
        'when a port 443 request with ESCR and both sides authenticating '
        'arrives, then srvd answers it and records the session', () async {
      final id = Uuid().v4();
      await srvd.handleRequestPorts(requestPorts(id));
      await pumpEventQueue();
      expect(srvd.sessions.containsKey(id), isTrue);
      expect(answered(id), isTrue);
      expect(nacked(id), isFalse);
    });

    test(
        'when the isolate refuses to start a session srvd has recorded, '
        'then srvd forgets it and keeps the sessions the isolate started',
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
      expect(srvd.sessions.containsKey(started), isTrue);
    });
  });
}
