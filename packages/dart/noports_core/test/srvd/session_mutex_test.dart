import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:at_commons/at_builders.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../sshnp/sshnp_mocks.dart';

class FakeNotificationParams extends Fake implements NotificationParams {}

class FakeAtKey extends Fake implements AtKey {}

class FakeVerbBuilder extends Fake implements VerbBuilder {}

class MockRemoteSecondary extends Mock implements RemoteSecondary {}

/// An srvd whose port pairs are a recorder of what srvd sends them.
class _RecordingSrvd extends SrvdImpl {
  _RecordingSrvd({required super.atClient})
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
        signingKeyCheckInterval: Duration.zero,
      ) {
    portPair.listen((m) {
      if (m is IIRequest) sentToPortPair.add(m);
    });
  }

  final ReceivePort portPair = ReceivePort();
  final List<IIRequest> sentToPortPair = [];

  @override
  Future<(PortPair, Isolate, SendPort)> spawnNewPortPairIsolate(
    SrvdSessionParams sessionParams,
  ) async => ((40001, 40002), Isolate.current, portPair.sendPort);
}

void main() {
  late MockAtClient atClient;
  late MockRemoteSecondary remote;
  late MockNotificationService notificationService;
  late List<NotificationParams> notified;
  late _RecordingSrvd srvd;

  setUpAll(() {
    registerFallbackValue(FakeNotificationParams());
    registerFallbackValue(FakeAtKey());
    registerFallbackValue(FakeVerbBuilder());
  });

  setUp(() async {
    atClient = MockAtClient();
    remote = MockRemoteSecondary();
    notificationService = MockNotificationService();
    notified = [];
    when(() => atClient.getCurrentAtSign()).thenReturn('@relay');
    when(() => atClient.getRemoteSecondary()).thenReturn(remote);
    when(() => atClient.notificationService).thenReturn(notificationService);
    when(
      () => atClient.get(
        any(),
        getRequestOptions: any(named: 'getRequestOptions'),
      ),
    ).thenAnswer((_) async => AtValue()..value = 'a public key');
    when(
      () => notificationService.notify(
        any(),
        checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
        waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
        onSentToSecondary: any(named: 'onSentToSecondary'),
      ),
    ).thenAnswer((i) async {
      notified.add(i.positionalArguments[0]);
      return NotificationResult()
        ..notificationStatusEnum = NotificationStatusEnum.delivered;
    });
    srvd = _RecordingSrvd(atClient: atClient);
    await srvd.init();
    addTearDown(srvd.portPair.close);
  });

  AtNotification requestPorts(
    String sessionId, {
    required bool multipleAcksOk,
  }) => AtNotification(
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
      'authenticateSocketB': true,
      'relayAuthMode': RelayAuthMode.escr.name,
      'only443': false,
      'multipleAcksOk': multipleAcksOk,
    }),
  );

  bool answered(String sessionId) =>
      notified.any((n) => n.atKey.key == sessionId);

  bool portPairStopped() => srvd.sentToPortPair.any((m) => m.type == 'stop');

  group('Given a client that takes one ack and no lock for its session', () {
    test(
      'when srvd receives request_ports, then it takes the lock as an'
      ' immutable record with a 30 s ttl and no commit, and answers',
      () async {
        when(() => remote.executeVerb(any())).thenAnswer((_) async => '-1');
        final id = Uuid().v4();

        await srvd.handleRequestPorts(requestPorts(id, multipleAcksOk: false));
        await pumpEventQueue();

        final lock =
            verify(() => remote.executeVerb(captureAny())).captured.single
                as UpdateVerbBuilder;
        expect(lock.atKey.toString(), '$id.session_mutexes.sshrvd@relay');
        expect(lock.atKey.metadata.immutable, isTrue);
        expect(lock.atKey.metadata.ttl, 30000);
        expect(lock.noCommit, isTrue);
        expect(answered(id), isTrue);
        expect(srvd.sessions.containsKey(id), isTrue);
        expect(portPairStopped(), isFalse);
      },
    );
  });

  group('Given another srvd holds the session lock', () {
    test('when srvd receives request_ports, then it stops the port pair it'
        ' spawned and does not answer', () async {
      when(
        () => remote.executeVerb(any()),
      ).thenThrow(AtException('Immutable records may not be updated'));
      final id = Uuid().v4();

      await srvd.handleRequestPorts(requestPorts(id, multipleAcksOk: false));
      await pumpEventQueue();

      expect(portPairStopped(), isTrue);
      expect(answered(id), isFalse);
      expect(srvd.sessions.containsKey(id), isFalse);
    });
  });

  group('Given the session lock fails for another reason', () {
    test('when srvd receives request_ports, then it stops the port pair it'
        ' spawned and does not answer', () async {
      when(
        () => remote.executeVerb(any()),
      ).thenThrow(AtTimeoutException('no answer from the atServer'));
      final id = Uuid().v4();

      await srvd.handleRequestPorts(requestPorts(id, multipleAcksOk: false));
      await pumpEventQueue();

      expect(portPairStopped(), isTrue);
      expect(answered(id), isFalse);
      expect(srvd.sessions.containsKey(id), isFalse);
    });
  });

  group('Given a client that takes several acks', () {
    test(
      'when srvd receives request_ports, then it takes no lock and answers',
      () async {
        final id = Uuid().v4();

        await srvd.handleRequestPorts(requestPorts(id, multipleAcksOk: true));
        await pumpEventQueue();

        verifyNever(() => remote.executeVerb(any()));
        expect(answered(id), isTrue);
      },
    );
  });
}
