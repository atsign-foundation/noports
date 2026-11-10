import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_params.dart'
    show defaultSigningKeyCheckInterval;
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

/// An srvd that counts its signing-key checks instead of making them.
class _CountingSrvd extends SrvdImpl {
  _CountingSrvd({required super.atClient})
      : super(
          atSign: '@relay'.toAtsign(),
          homeDirectory: Directory.current.path,
          atKeysFilePath: Directory.current.path,
          managerAtsign: 'open',
          ipAddress: '127.0.0.1',
          logTraffic: false,
          verbose: false,
          bind443: false,
          localBindPort443: 0,
          relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
          signingKeyCheckInterval: const Duration(milliseconds: 10),
        );

  int checks = 0;

  @override
  Future<void> checkSigningKeys() async => checks++;
}

void main() {
  late List<StreamController<AtNotification>> subscriptions;
  late MockAtClient atClient;

  setUp(() {
    subscriptions = [];
    atClient = MockAtClient();
    final notificationService = MockNotificationService();
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

  SrvdImpl srvd({bool bind443 = false, int localBindPort443 = 0}) => SrvdImpl(
        atClient: atClient,
        atSign: '@relay'.toAtsign(),
        homeDirectory: Directory.current.path,
        atKeysFilePath: Directory.current.path,
        managerAtsign: 'open',
        ipAddress: '127.0.0.1',
        logTraffic: false,
        verbose: false,
        bind443: bind443,
        localBindPort443: localBindPort443,
        relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
        signingKeyCheckInterval: defaultSigningKeyCheckInterval,
      );

  SrvdSessionParams session() => SrvdSessionParams(
        sessionId: 'the session',
        atSignA: '@alice',
        atSignB: '@bob',
        rvdNonce: 'rvd nonce',
        only443: false,
        multipleAcksOk: true,
        preFetch: const [],
        sendJsonResponse: true,
      );

  /// Waits up to 5 seconds for [relay] to have no running workers.
  Future<int> untilNoWorkers(SrvdImpl relay) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (relay.runningWorkers > 0 && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    return relay.runningWorkers;
  }

  /// Completes when [isolate] exits.
  Future<void> exitOf(Isolate isolate) {
    final exited = ReceivePort();
    isolate.addOnExitListener(exited.sendPort);
    return exited.first.then((_) => exited.close());
  }

  test('stop() cancels the subscriptions and ends session isolates', () async {
    final relay = srvd();
    await relay.init();
    await relay.run();
    final ((portA, _), isolate, _) =
        await relay.spawnNewPortPairIsolate(session());
    final exited = exitOf(isolate);
    final control = await Socket.connect(InternetAddress.loopbackIPv4, portA);
    addTearDown(control.destroy);
    expect(subscriptions.where((c) => c.hasListener), hasLength(2));
    expect(relay.runningWorkers, 1);
    relay.sessions['a session with no worker'] = SessionInfo(
      params: session(),
      connector: null,
    );

    await relay.stop();

    await exited.timeout(const Duration(seconds: 5));
    expect(subscriptions.where((c) => c.hasListener), isEmpty);
    expect(relay.runningWorkers, 0);
    expect(relay.sessions, isEmpty);
    await expectLater(
      Socket.connect(InternetAddress.loopbackIPv4, portA),
      throwsA(isA<SocketException>()),
    );
  });

  test('A run after a stop subscribes to nothing and starts no timer',
      () async {
    final running = _CountingSrvd(atClient: atClient);
    await running.init();
    await running.run();
    addTearDown(running.stop);
    final listeningWhileRunning =
        subscriptions.where((c) => c.hasListener).length;
    final stopped = _CountingSrvd(atClient: atClient);
    await stopped.init();
    await stopped.stop();

    await stopped.run();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(running.checks, greaterThan(0),
        reason: 'the control: a running relay checks its signing keys');
    expect(listeningWhileRunning, 2);
    expect(subscriptions.where((c) => c.hasListener), hasLength(2),
        reason: 'only the running relay is subscribed');
    expect(stopped.checks, 0,
        reason: 'a relay run after its stop starts no signing-key timer');
  });

  test('a worker whose session ends is forgotten', () async {
    final relay = srvd();
    await relay.init();
    final (_, isolate, toWorker) =
        await relay.spawnNewPortPairIsolate(session());
    final exited = exitOf(isolate);
    expect(relay.runningWorkers, 1);

    toWorker.send(IIRequest.create('stop', null));
    await exited.timeout(const Duration(seconds: 5));
    await Future.delayed(Duration.zero);

    expect(relay.runningWorkers, 0);
  });

  test('stop() during a session spawn leaves no worker running', () async {
    final relay = srvd();
    await relay.init();
    final spawning = relay.spawnNewPortPairIsolate(session());

    await relay.stop();

    await expectLater(spawning, throwsA(isA<StateError>()));
    expect(await untilNoWorkers(relay), 0);
  });

  test('stop() ends the 443 isolate and closes its port', () async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    final relay = srvd(bind443: true, localBindPort443: port);
    await relay.init();
    final exited = exitOf(relay.isolate443!);
    // NOTE the worker binds its port after init() returns, so retry briefly.
    Socket? control;
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (control == null && DateTime.now().isBefore(deadline)) {
      try {
        control = await Socket.connect(InternetAddress.loopbackIPv4, port);
      } on SocketException {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
    expect(control, isNotNull, reason: 'the 443 worker never listened');
    addTearDown(control!.destroy);

    await relay.stop();

    await exited.timeout(const Duration(seconds: 5));
    await expectLater(
      Socket.connect(InternetAddress.loopbackIPv4, port),
      throwsA(isA<SocketException>()),
    );
  });
}
