import 'dart:async';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/srv.dart';
import 'package:noports_core/srvd.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../../sshnp_mocks.dart';
import 'srvd_channel_mocks.dart';

class FakeNotificationParams extends Fake implements NotificationParams {}

void main() {
  group('SrvdChannel', () {
    late SrvGeneratorStub<String> srvGeneratorStub;
    late MockAtClient mockAtClient;
    late StreamController<AtNotification> notificationStreamController;
    late NotifyStub notifyStub;
    late SubscribeStub subscribeStub;
    late MockSshnpParams mockParams;
    late String sessionId;
    late StubbedSrvdChannel stubbedSrvdChannel;
    late MockSrv<String> mockSrv;

    // Invocation patterns as closures so they can be referred to by name
    // instead of explicitly writing these calls several times in the test
    notifyInvocation() => notifyStub(
          any(),
          any(),
          checkForFinalDeliveryStatus:
              any(named: 'checkForFinalDeliveryStatus'),
          waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
          ttln: any(named: 'ttln'),
        );
    subscribeInvocation() => subscribeStub(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'),
        );
    srvGeneratorInvocation() => srvGeneratorStub(any(), any(),
        localPort: any(named: 'localPort'),
        bindLocalPort: any(named: 'bindLocalPort'),
        rvdAuthString: any(named: 'rvdAuthString'));
    srvRunInvocation() => mockSrv.run();

    setUp(() {
      srvGeneratorStub = SrvGeneratorStub();
      mockAtClient = MockAtClient();
      notificationStreamController = StreamController();
      notifyStub = NotifyStub();
      subscribeStub = SubscribeStub();
      mockParams = MockSshnpParams();
      when(() => mockParams.verbose).thenReturn(false);
      sessionId = Uuid().v4();
      mockSrv = MockSrv();

      stubbedSrvdChannel = StubbedSrvdChannel<String>(
        atClient: mockAtClient,
        params: mockParams,
        sessionId: sessionId,
        srvGenerator: srvGeneratorStub,
        notify: notifyStub,
        subscribe: subscribeStub,
      );

      registerFallbackValue(AtKey());
      registerFallbackValue(Duration(minutes: 1));
      registerFallbackValue(NotificationParams.forUpdate(AtKey()));

      // Create an AtChops instance for testing
      AtEncryptionKeyPair encryptionKeyPair =
          AtChopsUtil.generateAtEncryptionKeyPair();

      AtChops atChops = AtChopsImpl(
        AtChopsKeys.create(encryptionKeyPair, null),
      );

      when(() => mockAtClient.atChops).thenReturn(atChops);
    });

    test('public API', () {
      // This doesn't cover the full public API, but it covers all of the public
      // members which do not need further tests

      // Base type
      expect(stubbedSrvdChannel, isA<SrvdChannel<String>>());
      expect(stubbedSrvdChannel, isA<AsyncInitialization>());
      expect(stubbedSrvdChannel, isA<AtClientBindings>());

      // final params
      expect(stubbedSrvdChannel.logger, isA<AtSignLogger>());
      expect(
        stubbedSrvdChannel.srvGenerator,
        isA<
            Srv<String> Function(String, int,
                {required int localPort,
                required bool bindLocalPort,
                String? rvdAuthString})>(),
      );
      expect(stubbedSrvdChannel.atClient, mockAtClient);
      expect(stubbedSrvdChannel.params, mockParams);
      expect(stubbedSrvdChannel.sessionId, sessionId);
    }); // test public API

    whenInitializationWithSrvdHost() {
      when(() => mockParams.srvdAtSign).thenReturn('@srvd');
      when(() => mockParams.device).thenReturn('mydevice');
      when(() => mockParams.clientAtSign).thenReturn('@client');
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');
      when(() => mockParams.authenticateDeviceToRvd).thenReturn(true);
      when(() => mockParams.authenticateClientToRvd).thenReturn(true);
      when(() => mockParams.encryptRvdTraffic).thenReturn(true);
      when(() => mockParams.sendSshPublicKey).thenReturn(false);

      when(subscribeInvocation)
          .thenAnswer((_) => notificationStreamController.stream);

      when(notifyInvocation).thenAnswer(
        (_) async {
          final testIp = '123.123.123.123';
          final portA = 10456;
          final portB = 10789;
          final rvdSessionNonce = DateTime.now().toIso8601String();

          notificationStreamController.add(
            AtNotification.empty()
              ..id = Uuid().v4()
              ..key = '$sessionId.${Srvd.namespace}'
              ..from = '@srvd'
              ..to = '@client'
              ..epochMillis = DateTime.now().millisecondsSinceEpoch
              ..value = '$testIp,$portA,$portB,$rvdSessionNonce',
          );
        },
      );
    }

    test('Initialization - srvd host', () async {
      /// Set the required parameters
      whenInitializationWithSrvdHost();
      expect(stubbedSrvdChannel.srvdAck, SrvdAck.notAcknowledged);
      expect(stubbedSrvdChannel.initializeStarted, false);

      verifyNever(subscribeInvocation);
      verifyNever(notifyInvocation);

      await expectLater(stubbedSrvdChannel.initialize(), completes);

      verifyInOrder([
        () => subscribeStub(
            regex: '$sessionId.${Srvd.namespace}@', shouldDecrypt: true),
        () => notifyStub(
              any<AtKey>(
                that: predicate(
                  // Predicate matching specifically the srvdIdKey format
                  (AtKey key) =>
                      key.key == 'mydevice.request_ports.${Srvd.namespace}' &&
                      key.sharedBy == '@client' &&
                      key.sharedWith == '@srvd' &&
                      key.metadata.namespaceAware == false &&
                      key.metadata.ttl == 10000,
                ),
              ),
              any(),
              checkForFinalDeliveryStatus:
                  any(named: 'checkForFinalDeliveryStatus'),
              waitForFinalDeliveryStatus:
                  any(named: 'waitForFinalDeliveryStatus'),
              ttln: any(named: 'ttln'),
            ),
      ]);

      verifyNever(subscribeInvocation);
      verifyNever(notifyInvocation);

      expect(stubbedSrvdChannel.srvdAck, SrvdAck.acknowledged);
      expect(stubbedSrvdChannel.rvdHost, '123.123.123.123');
      expect(stubbedSrvdChannel.clientPort, 10456);
      expect(stubbedSrvdChannel.daemonPort, 10789);
    }); // test Initialization - srvd host

    test('Initialization completes - srvd host', () async {
      /// Set the required parameters
      whenInitializationWithSrvdHost();
      await expectLater(stubbedSrvdChannel.callInitialization(), completes);
      await expectLater(stubbedSrvdChannel.initialized, completes);
    });

    test('runSrv', () async {
      whenInitializationWithSrvdHost();

      await expectLater(stubbedSrvdChannel.callInitialization(), completes);
      expect(stubbedSrvdChannel.srvdAck, SrvdAck.acknowledged);
      await expectLater(stubbedSrvdChannel.initialized, completes);
      // Initialization should be complete
      // Begin test for [runSrv()]

      when(srvGeneratorInvocation).thenReturn(mockSrv);
      when(srvRunInvocation).thenAnswer((_) async => 'called srv run');

      verifyNever(srvGeneratorInvocation);
      verifyNever(srvRunInvocation);

      await expectLater(
        await stubbedSrvdChannel.runSrv(),
        'called srv run',
      );

      verifyInOrder([
        srvGeneratorInvocation,
        srvRunInvocation,
      ]);

      verifyNever(srvGeneratorInvocation);
      verifyNever(srvRunInvocation);
    }); // test runSrv
  }); // group SrvdChannel

  group('A group of tests to assert notifications received from the srvd', () {
    test(
        'A test to assert getHostAndPortFromSrvd sets host and ports received from srvd via notification',
        () async {
      registerFallbackValue(FakeNotificationParams());
      String sessionId = 'dummy-session-id';
      MockAtClient mockAtClient = MockAtClient();
      MockNotificationService mockNotificationService =
          MockNotificationService();

      when(() => mockAtClient.notificationService)
          .thenReturn(mockNotificationService);

      when(() => mockNotificationService.notify(any(),
          checkForFinalDeliveryStatus:
              any(named: 'checkForFinalDeliveryStatus'),
          waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
          onSuccess: any(named: 'onSuccess'),
          onError: any(named: 'onError'),
          onSentToSecondary:
              any(named: 'onSentToSecondary'))).thenAnswer((_) async =>
          Future.value(NotificationResult()
            ..notificationStatusEnum = NotificationStatusEnum.delivered));

      // Create a stream controller to simulate the notification received from the srvd
      // which contains the host and port numbers.
      final streamController = StreamController<AtNotification>();
      streamController.add(AtNotification(
          '123',
          'local.request_ports.${Srvd.namespace}',
          '@alice',
          '@bob',
          123,
          'key',
          true)
        ..value = '127.0.0.1,98878,98879,rvd_dummy_nonce');
      when(() => mockNotificationService.subscribe(
              regex: any(named: 'regex'),
              shouldDecrypt: any(named: 'shouldDecrypt')))
          .thenAnswer((_) => streamController.stream);

      SrvdChannelParams srvdChannelParams = NptParams(
          clientAtSign: '@sshnp',
          sshnpdAtSign: '@sshnpd',
          srvdAtSign: '@srvd',
          remoteHost: '127.0.0.1',
          remotePort: 9887,
          device: 'my_device1',
          inline: true,
          timeout: Duration(seconds: 30));
      SrvdDartBindPortChannel srvdDartBindPortChannel = SrvdDartBindPortChannel(
          atClient: mockAtClient,
          params: srvdChannelParams,
          sessionId: sessionId);
      await srvdDartBindPortChannel.getHostAndPortFromSrvd();
      expect(srvdDartBindPortChannel.rvdHost, '127.0.0.1');
      expect(srvdDartBindPortChannel.clientPort, 98878);
      expect(srvdDartBindPortChannel.daemonPort, 98879);
      expect(srvdDartBindPortChannel.rvdNonce, 'rvd_dummy_nonce');
      expect(srvdDartBindPortChannel.fetched, true);
      expect(srvdDartBindPortChannel.srvdAck, SrvdAck.acknowledged);
    });

    test('A test to verify timeout exception when srvd does not respond',
        () async {
      registerFallbackValue(FakeNotificationParams());

      String sessionId = 'dummy-session-id';
      MockAtClient mockAtClient = MockAtClient();
      MockNotificationService mockNotificationService =
          MockNotificationService();

      when(() => mockNotificationService.subscribe(
              regex: any(named: 'regex'),
              shouldDecrypt: any(named: 'shouldDecrypt')))
          .thenAnswer((_) => StreamController<AtNotification>().stream);

      when(() => mockNotificationService.notify(any(),
          checkForFinalDeliveryStatus:
              any(named: 'checkForFinalDeliveryStatus'),
          waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
          onSuccess: any(named: 'onSuccess'),
          onError: any(named: 'onError'),
          onSentToSecondary:
              any(named: 'onSentToSecondary'))).thenAnswer((_) async =>
          Future.value(NotificationResult()
            ..notificationStatusEnum = NotificationStatusEnum.delivered));

      when(() => mockAtClient.notificationService)
          .thenReturn(mockNotificationService);

      SrvdChannelParams srvdChannelParams = NptParams(
          clientAtSign: '@sshnp',
          sshnpdAtSign: '@sshnpd',
          srvdAtSign: '@srvd',
          remoteHost: '127.0.0.1',
          remotePort: 9887,
          device: 'my_device1',
          inline: true,
          timeout: Duration(seconds: 30));

      when(() => mockAtClient.notificationService)
          .thenReturn(mockNotificationService);

      SrvdDartBindPortChannel srvdDartBindPortChannel = SrvdDartBindPortChannel(
          atClient: mockAtClient,
          params: srvdChannelParams,
          sessionId: sessionId);

      expect(
          () async => await srvdDartBindPortChannel.getHostAndPortFromSrvd(),
          throwsA(predicate((dynamic e) =>
              e is TimeoutException &&
              e.message == 'Connection timeout to srvd @srvd service')));
      expect(srvdDartBindPortChannel.srvdAck, SrvdAck.notAcknowledged);
    });
  });
}

class FakeNotificationParamsMatcher extends Matcher {
  @override
  Description describe(Description description) {
    return description;
  }

  @override
  bool matches(item, Map matchState) {
    if (item is NotificationParams) {
      return true;
    }
    return false;
  }
}
