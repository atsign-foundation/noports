import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
// ignore: implementation_imports
import 'package:at_client/src/client/remote_secondary.dart';
import 'package:at_commons/at_builders.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/srvd.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_params.dart'
    show defaultSigningKeyCheckInterval;
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

/// Sends its port to main, then ignores every message, so it never reports
/// its session complete and never exits on its own.
void _deafWorker(SendPort toMain) {
  final fromMain = ReceivePort();
  toMain.send(fromMain.sendPort);
  fromMain.listen((_) {});
}

class _FakeNotificationParams extends Fake implements NotificationParams {}

class _FakeVerbBuilder extends Fake implements VerbBuilder {}

class _MockRemoteSecondary extends Mock implements RemoteSecondary {}

/// An srvd that notes each session main receives sessionComplete for.
class _RecordingSrvd extends SrvdImpl {
  _RecordingSrvd({
    required super.atClient,
    required super.atSign,
    required super.homeDirectory,
    required super.atKeysFilePath,
    required super.managerAtsign,
    required super.ipAddress,
    required super.logTraffic,
    required super.verbose,
    required super.bind443,
    required super.localBindPort443,
    required super.relayAuthDetectWindowMs,
    required super.signingKeyCheckInterval,
  });

  final Set<String> completed = {};

  /// While set, a session request waits on it before it is started.
  Future<void>? holdRequests;

  @override
  Future<SrvdSessionParams> withPayloadKeys(SrvdSessionParams params) async {
    final hold = holdRequests;
    if (hold != null) await hold;
    return super.withPayloadKeys(params);
  }

  @override
  Future<void> handleWorkerReport(IIRequest msg) {
    if (msg.type == 'sessionComplete') completed.add(msg.payload['sessionId']);
    return super.handleWorkerReport(msg);
  }
}

void main() {
  late List<StreamController<AtNotification>> subscriptions;
  late MockAtClient atClient;
  late List<NotificationParams> answers;
  final sockets = <Socket>[];

  setUpAll(() {
    registerFallbackValue(_FakeNotificationParams());
    registerFallbackValue(_FakeVerbBuilder());
  });

  setUp(() {
    subscriptions = [];
    answers = [];
    atClient = MockAtClient();
    final notificationService = MockNotificationService();
    when(
      () => notificationService.notify(
        any(),
        checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
        waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
        onSentToSecondary: any(named: 'onSentToSecondary'),
      ),
    ).thenAnswer((i) async {
      answers.add(i.positionalArguments.first as NotificationParams);
      return NotificationResult()
        ..notificationStatusEnum = NotificationStatusEnum.delivered;
    });
    when(() => atClient.notificationService).thenReturn(notificationService);
    when(
      () => notificationService.subscribe(
        regex: any(named: 'regex'),
        shouldDecrypt: any(named: 'shouldDecrypt'),
      ),
    ).thenAnswer((_) {
      final controller = StreamController<AtNotification>.broadcast();
      subscriptions.add(controller);
      return controller.stream;
    });
  });

  tearDown(() {
    for (final s in sockets) {
      s.destroy();
    }
    sockets.clear();
  });

  _RecordingSrvd srvd({bool bind443 = false}) => _RecordingSrvd(
        atClient: atClient,
        atSign: '@relay'.toAtsign(),
        homeDirectory: Directory.current.path,
        atKeysFilePath: Directory.current.path,
        managerAtsign: 'open',
        ipAddress: '127.0.0.1',
        logTraffic: false,
        verbose: false,
        bind443: bind443,
        localBindPort443: 0,
        relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
        signingKeyCheckInterval: defaultSigningKeyCheckInterval,
      );

  SrvdSessionParams session(String id) => SrvdSessionParams(
        sessionId: id,
        atSignA: '@alice',
        atSignB: '@bob',
        rvdNonce: 'rvd nonce',
        only443: false,
        multipleAcksOk: true,
        preFetch: const [],
        sendJsonResponse: true,
      );

  /// Spawns a session's worker, records the session as a request would, and
  /// pairs one connection on it; returns the session and its client socket.
  Future<(SessionInfo, Socket)> liveSession(SrvdImpl relay, String id) async {
    final ((portA, portB), _, toWorker) =
        await relay.spawnNewPortPairIsolate(session(id));
    final si = SessionInfo(
      params: session(id),
      connector: null,
      toWorker: toWorker,
    );
    relay.sessions[id] = si;
    final client = await Socket.connect(InternetAddress.loopbackIPv4, portA);
    final device = await Socket.connect(InternetAddress.loopbackIPv4, portB);
    sockets.addAll([client, device]);
    device.listen((_) {});
    return (si, client);
  }

  /// Completes when [socket]'s peer has closed it.
  Future<void> closedByPeer(Socket socket) {
    final done = Completer<void>();
    socket.listen(
      (_) {},
      onDone: () => done.isCompleted ? null : done.complete(),
      onError: (_) => done.isCompleted ? null : done.complete(),
    );
    return done.future;
  }

  test(
      'A stop closes every connection, waits for each completion, and returns'
      ' within 12 seconds', () async {
    final relay = srvd();
    await relay.init();
    await relay.run();
    final (_, clientOne) = await liveSession(relay, 'one');
    final (_, clientTwo) = await liveSession(relay, 'two');
    final clientsClosed = [closedByPeer(clientOne), closedByPeer(clientTwo)];
    expect(subscriptions.where((c) => c.hasListener), hasLength(2));
    final stopwatch = Stopwatch()..start();

    await relay.stop();

    stopwatch.stop();
    expect(stopwatch.elapsed, lessThan(Srvd.stopBound));
    expect(subscriptions.where((c) => c.hasListener), isEmpty);
    expect(relay.completed, containsAll(<String>['one', 'two']),
        reason: 'main received sessionComplete for each before forgetting it');
    expect(relay.sessions, isEmpty);
    expect(relay.runningWorkers, 0);
    await Future.wait(clientsClosed).timeout(const Duration(seconds: 3));
  });

  test(
      'A worker that never completes is killed and the stop still returns'
      ' within 12 seconds', () async {
    final relay = srvd();
    await relay.init();
    final fromWorker = ReceivePort();
    final exitPort = ReceivePort();
    final toWorker = Completer<SendPort>();
    fromWorker.listen((m) {
      if (m is SendPort) toWorker.complete(m);
    });
    final deaf = await Isolate.spawn(
      _deafWorker,
      fromWorker.sendPort,
      onExit: exitPort.sendPort,
    );
    final exitWatch = ReceivePort();
    deaf.addOnExitListener(exitWatch.sendPort);
    final exited = exitWatch.first;
    final logged = <String>[];
    relay.logger.logger.onRecord.listen((r) => logged.add(r.message));
    relay.trackWorker(deaf, fromWorker, exitPort, toWorker.future,
        sessionId: 'deaf-session');
    await toWorker.future.timeout(const Duration(seconds: 2));
    expect(relay.runningWorkers, 1);
    final stopwatch = Stopwatch()..start();

    await relay.stop();

    stopwatch.stop();
    expect(stopwatch.elapsed, lessThan(Srvd.stopBound));
    await exited.timeout(const Duration(seconds: 2));
    exitWatch.close();
    expect(
      logged.where((m) => m.contains('killed') && m.contains('deaf-session')),
      hasLength(1),
      reason: 'the warning names the worker by the session it carries',
    );
  });

  test('A session request arriving during a stop is refused', () async {
    final relay = srvd();
    await relay.init();
    await relay.run();
    final stopping = relay.stop();

    await relay.handleRequestPorts(AtNotification(
      'notif-id',
      '@relay:gateway-1.request_ports.sshrvd@alice',
      '@alice',
      '@relay',
      DateTime.now().millisecondsSinceEpoch,
      'key',
      true,
      value: jsonEncode({
        'sessionId': 'late',
        'atSignA': '@alice',
        'atSignB': '@bob',
        'clientNonce': 'client nonce',
        'authenticateSocketA': false,
        'authenticateSocketB': false,
        'relayAuthMode': RelayAuthMode.escr.name,
        'only443': false,
        'multipleAcksOk': true,
      }),
    ));
    await stopping;

    expect(answers, isEmpty, reason: 'the client is sent no ports');
    expect(relay.sessions, isEmpty);
    expect(relay.runningWorkers, 0);
  });

  test(
      'A port-443 session request still being prepared when a stop begins is'
      ' refused', () async {
    final relay = srvd(bind443: true);
    await relay.init();
    await relay.run();
    final hold = Completer<void>();
    relay.holdRequests = hold.future;
    final requesting = relay.handleRequestPorts(AtNotification(
      'notif-id',
      '@relay:gateway-1.request_ports.sshrvd@alice',
      '@alice',
      '@relay',
      DateTime.now().millisecondsSinceEpoch,
      'key',
      true,
      value: jsonEncode({
        'sessionId': 'late',
        'atSignA': '@alice',
        'atSignB': '@bob',
        'clientNonce': 'client nonce',
        'authenticateSocketA': true,
        'authenticateSocketB': true,
        'relayAuthMode': RelayAuthMode.escr.name,
        'only443': true,
        'multipleAcksOk': true,
      }),
    ));
    await pumpEventQueue();

    final stopping = relay.stop();
    hold.complete();
    await requesting;
    await stopping;

    expect(answers, isEmpty, reason: 'the client is sent no ports');
    expect(relay.sessions, isEmpty);
  });

  test(
      'A session request whose ports arrive as a stop begins takes no session'
      ' mutex', () async {
    when(() => atClient.getCurrentAtSign()).thenReturn('@relay');
    final remote = _MockRemoteSecondary();
    when(() => atClient.getRemoteSecondary()).thenReturn(remote);
    when(() => remote.executeVerb(any())).thenAnswer((_) async => 'data:1');
    final relay = srvd();
    await relay.init();
    await relay.run();
    bool stopBegun = false;
    relay.logger.logger.onRecord.listen((r) {
      if (r.message.startsWith('Received ports')) {
        stopBegun = true;
        unawaited(relay.stop());
      }
    });

    await relay.handleRequestPorts(AtNotification(
      'notif-id',
      '@relay:gateway-1.request_ports.sshrvd@alice',
      '@alice',
      '@relay',
      DateTime.now().millisecondsSinceEpoch,
      'key',
      true,
      value: jsonEncode({
        'sessionId': 'spawning',
        'atSignA': '@alice',
        'atSignB': '@bob',
        'clientNonce': 'client nonce',
        'authenticateSocketA': false,
        'authenticateSocketB': false,
        'relayAuthMode': RelayAuthMode.escr.name,
        'only443': false,
        'multipleAcksOk': false,
      }),
    ));
    await relay.stop();

    expect(stopBegun, isTrue,
        reason: 'the stop began once the worker had reported its ports');
    verifyNever(() => remote.executeVerb(any()));
    expect(answers, isEmpty, reason: 'the client is sent no ports');
    expect(relay.sessions, isEmpty);
  });
}
