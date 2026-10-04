import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

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

  SrvdImpl srvd({bool bind443 = false}) => SrvdImpl(
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

    await relay.stop();

    await exited.timeout(const Duration(seconds: 5));
    expect(subscriptions.where((c) => c.hasListener), isEmpty);
    expect(relay.runningWorkers, 0);
    await expectLater(
      Socket.connect(InternetAddress.loopbackIPv4, portA),
      throwsA(isA<SocketException>()),
    );
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

  test('stop() ends the 443 isolate', () async {
    final relay = srvd(bind443: true);
    await relay.init();
    final exited = exitOf(relay.isolate443!);

    await relay.stop();

    await exited.timeout(const Duration(seconds: 5));
  });
}
