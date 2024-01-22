import 'dart:async';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:noports_core/srv.dart';
import 'package:noports_core/srvd.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../../sshnp_mocks.dart';
import 'srvd_channel_mocks.dart';

void main() {
  group('SshrvdChannel', () {
    late SshrvGeneratorStub<String> sshrvGeneratorStub;
    late MockAtClient mockAtClient;
    late StreamController<AtNotification> notificationStreamController;
    late NotifyStub notifyStub;
    late SubscribeStub subscribeStub;
    late MockSshnpParams mockParams;
    late String sessionId;
    late StubbedSshrvdChannel stubbedSshrvdChannel;
    late MockSshrv<String> mockSshrv;

    // Invocation patterns as closures so they can be referred to by name
    // instead of explicitly writing these calls several times in the test
    notifyInvocation() => notifyStub(
          any(),
          any(),
          checkForFinalDeliveryStatus:
              any(named: 'checkForFinalDeliveryStatus'),
          waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
        );
    subscribeInvocation() => subscribeStub(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'),
        );
    sshrvGeneratorInvocation() => sshrvGeneratorStub(any(), any(),
        localPort: any(named: 'localPort'),
        bindLocalPort: any(named: 'bindLocalPort'),
        rvdAuthString: any(named: 'rvdAuthString'));
    sshrvRunInvocation() => mockSshrv.run();

    setUp(() {
      sshrvGeneratorStub = SshrvGeneratorStub();
      mockAtClient = MockAtClient();
      notificationStreamController = StreamController();
      notifyStub = NotifyStub();
      subscribeStub = SubscribeStub();
      mockParams = MockSshnpParams();
      when(() => mockParams.verbose).thenReturn(false);
      sessionId = Uuid().v4();
      mockSshrv = MockSshrv();

      stubbedSshrvdChannel = StubbedSshrvdChannel<String>(
        atClient: mockAtClient,
        params: mockParams,
        sessionId: sessionId,
        sshrvGenerator: sshrvGeneratorStub,
        notify: notifyStub,
        subscribe: subscribeStub,
      );

      registerFallbackValue(AtKey());
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
      expect(stubbedSshrvdChannel, isA<SshrvdChannel<String>>());
      expect(stubbedSshrvdChannel, isA<AsyncInitialization>());
      expect(stubbedSshrvdChannel, isA<AtClientBindings>());

      // final params
      expect(stubbedSshrvdChannel.logger, isA<AtSignLogger>());
      expect(
        stubbedSshrvdChannel.sshrvGenerator,
        isA<
            Srv<String> Function(String, int,
                {required int localPort,
                required bool bindLocalPort,
                String? rvdAuthString})>(),
      );
      expect(stubbedSshrvdChannel.atClient, mockAtClient);
      expect(stubbedSshrvdChannel.params, mockParams);
      expect(stubbedSshrvdChannel.sessionId, sessionId);
    }); // test public API

    whenInitializationWithSshrvdHost() {
      when(() => mockParams.host).thenReturn('@sshrvd');
      when(() => mockParams.device).thenReturn('mydevice');
      when(() => mockParams.clientAtSign).thenReturn('@client');
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');
      when(() => mockParams.authenticateDeviceToRvd).thenReturn(true);
      when(() => mockParams.authenticateClientToRvd).thenReturn(true);
      when(() => mockParams.encryptRvdTraffic).thenReturn(true);
      when(() => mockParams.discoverDaemonFeatures).thenReturn(false);

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
              ..from = '@sshrvd'
              ..to = '@client'
              ..epochMillis = DateTime.now().millisecondsSinceEpoch
              ..value = '$testIp,$portA,$portB,$rvdSessionNonce',
          );
        },
      );
    }

    test('Initialization - sshrvd host', () async {
      /// Set the required parameters
      whenInitializationWithSshrvdHost();
      expect(stubbedSshrvdChannel.sshrvdAck, SshrvdAck.notAcknowledged);
      expect(stubbedSshrvdChannel.initializeStarted, false);

      verifyNever(subscribeInvocation);
      verifyNever(notifyInvocation);

      await expectLater(stubbedSshrvdChannel.initialize(), completes);

      verifyInOrder([
        () => subscribeStub(
            regex: '$sessionId.${Srvd.namespace}@', shouldDecrypt: true),
        () => notifyStub(
              any<AtKey>(
                that: predicate(
                  // Predicate matching specifically the sshrvdIdKey format
                  (AtKey key) =>
                      key.key == 'mydevice.request_ports.${Srvd.namespace}' &&
                      key.sharedBy == '@client' &&
                      key.sharedWith == '@sshrvd' &&
                      key.metadata != null &&
                      key.metadata!.namespaceAware == false &&
                      key.metadata!.ttl == 10000,
                ),
              ),
              any(),
              checkForFinalDeliveryStatus:
                  any(named: 'checkForFinalDeliveryStatus'),
              waitForFinalDeliveryStatus:
                  any(named: 'waitForFinalDeliveryStatus'),
            ),
      ]);

      verifyNever(subscribeInvocation);
      verifyNever(notifyInvocation);

      expect(stubbedSshrvdChannel.sshrvdAck, SshrvdAck.acknowledged);
      expect(stubbedSshrvdChannel.host, '123.123.123.123');
      expect(stubbedSshrvdChannel.port, 10456);
      expect(stubbedSshrvdChannel.sshrvdPort, 10789);
    }); // test Initialization - sshrvd host

    test('Initialization - non-sshrvd host', () async {
      when(() => mockParams.host).thenReturn('234.234.234.234');
      when(() => mockParams.port).thenReturn(135);

      await expectLater(stubbedSshrvdChannel.initialize(), completes);

      expect(stubbedSshrvdChannel.host, '234.234.234.234');
      expect(stubbedSshrvdChannel.port, 135);
    }); // test Initialization - non-sshrvd host

    test('Initialization completes - sshrvd host', () async {
      /// Set the required parameters
      whenInitializationWithSshrvdHost();
      await expectLater(stubbedSshrvdChannel.callInitialization(), completes);
      await expectLater(stubbedSshrvdChannel.initialized, completes);
    });

    test('Initialization completes - non-sshrvd host', () async {
      when(() => mockParams.host).thenReturn('234.234.234.234');
      when(() => mockParams.port).thenReturn(135);

      await expectLater(stubbedSshrvdChannel.callInitialization(), completes);
      await expectLater(stubbedSshrvdChannel.initialized, completes);
    }); // test Initialization - non-sshrvd host

    test('runSshrv', () async {
      whenInitializationWithSshrvdHost();

      await expectLater(stubbedSshrvdChannel.callInitialization(), completes);
      expect(stubbedSshrvdChannel.sshrvdAck, SshrvdAck.acknowledged);
      await expectLater(stubbedSshrvdChannel.initialized, completes);
      // Initialization should be complete
      // Begin test for [runSshrv()]

      when(() => mockParams.localSshdPort).thenReturn(23);
      when(sshrvGeneratorInvocation).thenReturn(mockSshrv);
      when(sshrvRunInvocation).thenAnswer((_) async => 'called sshrv run');

      verifyNever(sshrvGeneratorInvocation);
      verifyNever(sshrvRunInvocation);

      await expectLater(
        await stubbedSshrvdChannel.runSshrv(directSsh: false),
        'called sshrv run',
      );

      verifyInOrder([
        sshrvGeneratorInvocation,
        sshrvRunInvocation,
      ]);

      verifyNever(sshrvGeneratorInvocation);
      verifyNever(sshrvRunInvocation);
    }); // test runSshrv
  }); // group SshrvdChannel
}
