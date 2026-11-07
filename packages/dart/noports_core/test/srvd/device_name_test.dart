import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

class FakeNotificationParams extends Fake implements NotificationParams {}

/// An srvd whose port pairs come from nowhere, so a request gets as far as
/// being recorded as a session.
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
        );

  final ReceivePort portPair = ReceivePort();

  @override
  Future<(PortPair, Isolate, SendPort)> spawnNewPortPairIsolate(
    SrvdSessionParams sessionParams,
  ) async =>
      ((40001, 40002), Isolate.current, portPair.sendPort);
}

void main() {
  late _RecordingSrvd srvd;

  setUpAll(() => registerFallbackValue(FakeNotificationParams()));

  setUp(() async {
    final atClient = MockAtClient();
    final notificationService = MockNotificationService();
    when(() => atClient.notificationService).thenReturn(notificationService);
    when(
      () => notificationService.notify(
        any(),
        checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
        waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
        onSentToSecondary: any(named: 'onSentToSecondary'),
      ),
    ).thenAnswer(
      (_) async => NotificationResult()
        ..notificationStatusEnum = NotificationStatusEnum.delivered,
    );
    srvd = _RecordingSrvd(atClient: atClient);
    await srvd.init();
    addTearDown(srvd.portPair.close);
  });

  /// A session request from @alice whose key names [device].
  AtNotification requestPorts(String device) => AtNotification(
        'notif-id',
        '@relay:$device.request_ports.sshrvd@alice',
        '@alice',
        '@relay',
        DateTime.now().millisecondsSinceEpoch,
        'key',
        true,
        value: jsonEncode({
          'sessionId': 'the session',
          'atSignA': '@alice',
          'atSignB': '@bob',
          'clientNonce': 'client nonce',
          'authenticateSocketA': false,
          'authenticateSocketB': false,
          'relayAuthMode': RelayAuthMode.escr.name,
          'only443': false,
          'multipleAcksOk': true,
        }),
      );

  test("The device name comes from the session request's key", () async {
    await srvd.handleRequestPorts(requestPorts('gateway-1'));

    expect(srvd.sessions['the session']!.deviceName, 'gateway-1');
  });

  test('A device name that does not match the pattern is not recorded',
      () async {
    await srvd.handleRequestPorts(requestPorts('x'));

    expect(srvd.sessions['the session'], isNotNull, reason: 'the session starts');
    expect(srvd.sessions['the session']!.deviceName, isNull);
  });

  test('A device name the pattern matches only in part is not recorded',
      () async {
    await srvd.handleRequestPorts(requestPorts('a' * 37));

    expect(srvd.sessions['the session'], isNotNull, reason: 'the session starts');
    expect(srvd.sessions['the session']!.deviceName, isNull,
        reason: '37 characters is one over the bound');
  });

  test('The device name is lower-cased as the key is', () async {
    await srvd.handleRequestPorts(requestPorts('Gateway-1'));

    expect(srvd.sessions['the session']!.deviceName, 'gateway-1');
  });
}
