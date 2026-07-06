import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/sshnpd/sshnpd_impl.dart';
import 'package:test/test.dart';

class MockAtClient extends Mock implements AtClient {}

class MockNotificationService extends Mock implements NotificationService {}

class FakeNotificationParams extends Fake implements NotificationParams {}

class FakeAtKey extends Fake implements AtKey {}

void main() {
  group('sshnpd handles relay_latency_request', () {
    const String clientAtsign = '@client';
    const String deviceAtsign = '@testdevice';
    const String device = 'testdevice';

    late MockAtClient mockAtClient;
    late MockNotificationService mockNotificationService;
    late SshnpdImpl sshnpd;
    late List<NotificationParams> sentNotifications;

    setUpAll(() {
      registerFallbackValue(FakeNotificationParams());
      registerFallbackValue(FakeAtKey());
    });

    setUp(() {
      mockAtClient = MockAtClient();
      mockNotificationService = MockNotificationService();
      sentNotifications = [];

      when(() => mockAtClient.getCurrentAtSign()).thenReturn(deviceAtsign);
      when(
        () => mockAtClient.notificationService,
      ).thenReturn(mockNotificationService);

      // Capture every outgoing notify call for assertions.
      when(
        () => mockNotificationService.notify(
          any(),
          checkForFinalDeliveryStatus: any(
            named: 'checkForFinalDeliveryStatus',
          ),
          waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
          onSuccess: any(named: 'onSuccess'),
          onError: any(named: 'onError'),
          onSentToSecondary: any(named: 'onSentToSecondary'),
        ),
      ).thenAnswer((Invocation i) async {
        sentNotifications.add(i.positionalArguments[0] as NotificationParams);
        return NotificationResult()
          ..notificationStatusEnum = NotificationStatusEnum.delivered;
      });

      // clientAtsign is registered as a manager so authCheck short-circuits
      // to "authorized" without hitting any policy logic.
      sshnpd = SshnpdImpl(
        atClient: mockAtClient,
        username: 'testuser',
        homeDirectory: '/home/testuser',
        device: device,
        managerAtsigns: [clientAtsign],
        policyManagerAtsign: null,
        sshClient: SupportedSshClient.openssh,
        makeDeviceInfoVisible: false,
        addSshPublicKeys: false,
        localSshdPort: 22,
        sshPublicKeyPermissions: '',
        ephemeralPermissions: '',
        sshAlgorithm: SupportedSshAlgorithm.rsa,
        deviceGroup: 'default',
        version: '1.0.0',
        permitOpen: ['*:*'],
        strict: false,
      );
    });

    // Mirrors what RelaySelector.fetchDeviceLatency() sends in production:
    //   AtKey(key: 'relay_latency_request.<device>', sharedWith: device,
    //         sharedBy: client, namespace: sshnp)
    // which arrives at sshnpd with the key string serialized below.
    AtNotification latencyRequest({required String id, String? value}) {
      return AtNotification(
          id,
          '$deviceAtsign:relay_latency_request.$device.${DefaultArgs.namespace}$clientAtsign',
          clientAtsign, // from
          deviceAtsign, // to
          123,
          'key',
          true,
        )
        ..value = value;
    }

    Map<String, dynamic> decodeLatencyResponse(NotificationParams n) {
      expect(n.atKey.key, 'relay_latency_response.$device');
      expect(n.atKey.sharedWith, clientAtsign);
      expect(n.atKey.namespace, DefaultArgs.namespace);
      return jsonDecode(n.value!) as Map<String, dynamic>;
    }

    test('returns positive latency for a reachable RV', () async {
      // Real local listener — the probe should succeed quickly with latency ≥ 0.
      final listener = await ServerSocket.bind('127.0.0.1', 0);
      addTearDown(() async {
        await listener.close();
      });

      await sshnpd.clientRequestNotificationHandler(
        latencyRequest(
          id: 'aaaa1111-0000-0000-0000-000000000001',
          value: jsonEncode({
            '@rv1': {'ipaddr': '127.0.0.1', 'port': listener.port},
          }),
        ),
      );

      expect(sentNotifications, hasLength(1));
      final response = decodeLatencyResponse(sentNotifications.single);
      expect(response.containsKey('@rv1'), isTrue);
      expect(response['@rv1'], isA<int>());
      expect(response['@rv1'], greaterThanOrEqualTo(0));
    });

    test('returns -1 for an unreachable RV', () async {
      // Bind+close to get a definitely-free port, then connect — refused fast.
      final temp = await ServerSocket.bind('127.0.0.1', 0);
      final closedPort = temp.port;
      await temp.close();

      await sshnpd.clientRequestNotificationHandler(
        latencyRequest(
          id: 'aaaa1111-0000-0000-0000-000000000002',
          value: jsonEncode({
            '@rv1': {'ipaddr': '127.0.0.1', 'port': closedPort},
          }),
        ),
      );

      expect(sentNotifications, hasLength(1));
      final response = decodeLatencyResponse(sentNotifications.single);
      expect(response['@rv1'], -1);
    });

    test('sends no response when value is null', () async {
      await sshnpd.clientRequestNotificationHandler(
        latencyRequest(
          id: 'aaaa1111-0000-0000-0000-000000000003',
          value: null,
        ),
      );

      expect(sentNotifications, isEmpty);
    });

    test('sends no response when value is malformed JSON', () async {
      await sshnpd.clientRequestNotificationHandler(
        latencyRequest(
          id: 'aaaa1111-0000-0000-0000-000000000004',
          value: 'not-json',
        ),
      );

      expect(sentNotifications, isEmpty);
    });

    test('responds with empty map when rvServers is empty', () async {
      await sshnpd.clientRequestNotificationHandler(
        latencyRequest(
          id: 'aaaa1111-0000-0000-0000-000000000005',
          value: '{}',
        ),
      );

      expect(sentNotifications, hasLength(1));
      final response = decodeLatencyResponse(sentNotifications.single);
      expect(response, isEmpty);
    });
  });
}
