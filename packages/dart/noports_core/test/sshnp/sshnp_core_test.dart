import 'dart:async';
import 'dart:convert';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:at_commons/at_builders.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/features.dart';
import 'package:noports_core/srvd.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import 'sshnp_core_mocks.dart';
import 'sshnp_mocks.dart';
import 'util/sshnpd_channel/sshnpd_channel_mocks.dart';

class FakeScanVerbBuilder extends Fake implements ScanVerbBuilder {}

class FakeAtKey extends Fake implements AtKey {}

class FakeNotificationParams extends Fake implements NotificationParams {}

void main() {
  group('SshnpCore', () {
    /// Creation mocks
    late AtClient mockAtClient;
    late SshnpParams mockParams;
    late SshnpdChannel mockSshnpdChannel;
    late SrvdChannel mockSrvdChannel;

    /// Initialization stubs
    late FunctionStub<void> stubbedCallInitialization;
    late FunctionStub<void> stubbedInitialize;
    late FunctionStub<void> stubbedCompleteInitialization;

    setUp(() {
      /// Creation
      mockAtClient = MockAtClient();
      mockParams = MockSshnpParams();
      mockSshnpdChannel = MockSshnpdChannel();
      mockSrvdChannel = MockSrvdChannel();
      registerFallbackValue(AtClientPreference());

      /// Initialization
      stubbedCallInitialization = FunctionStub();
      stubbedInitialize = FunctionStub();
      stubbedCompleteInitialization = FunctionStub();
    });

    /// When declaration setup for the constructor of [StubbedSshnp]
    whenConstructor({bool verbose = false}) {
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');
      when(() => mockParams.device).thenReturn('mydevice');
      when(() => mockParams.localPort).thenReturn(0);
      when(() => mockParams.verbose).thenReturn(verbose);
      when(() => mockParams.authenticateDeviceToRvd).thenReturn(true);
      when(() => mockParams.authenticateClientToRvd).thenReturn(true);
      when(() => mockParams.encryptRvdTraffic).thenReturn(true);
      when(() => mockParams.sendSshPublicKey).thenReturn(false);
      when(() => mockAtClient.getPreferences()).thenReturn(null);
      when(() => mockAtClient.setPreferences(any())).thenReturn(null);
    }

    /// When declaration setup for the initialization of [StubbedSshnp]
    whenInitialization({AtSshKeyPair? identityKeyPair}) {
      when(() => stubbedCallInitialization()).thenAnswer((_) async {});
      when(() => stubbedInitialize()).thenAnswer((_) async {});
      when(() => stubbedCompleteInitialization()).thenReturn(null);

      when(() => mockSshnpdChannel.callInitialization())
          .thenAnswer((_) async {});
      when(() => mockSshnpdChannel.resolveRemoteUsername())
          .thenAnswer((_) async => 'myRemoteUsername');
      when(() => mockSshnpdChannel.resolveTunnelUsername(
              remoteUsername: any(named: 'remoteUsername')))
          .thenAnswer((_) async => 'myTunnelUsername');
      when(() => mockSshnpdChannel.sharePublicKeyIfRequired(
          identityKeyPair ?? any())).thenAnswer((_) async {});
      when(() => mockSshnpdChannel.featureCheck(any(),any())).thenAnswer((_) async {
        return DaemonFeature.values.map((f) => (f, true, 'mocked')).toList();
      });
      when(() => mockSrvdChannel.callInitialization()).thenAnswer((_) async {});
    }

    group('Constructor', () {
      test('verbose=false', () {
        whenConstructor(verbose: false);

        final sshnpCore = StubbedSshnp(
          atClient: mockAtClient,
          params: mockParams,
        );

        /// Expect that the namespace is set in the preferences
        verify(() => mockAtClient.getPreferences()).called(1);
        verify(() => mockParams.device).called(1);
        verify(() => mockAtClient.setPreferences(any())).called(1);

        /// Expect that the logger is configured correctly
        expect(sshnpCore.logger.logger.level, Level.SHOUT);
        expect(AtSignLogger.root_level, 'info');
      }); // test verbose=false

      test('verbose=true', () {
        whenConstructor(verbose: true);

        final sshnpCore = StubbedSshnp(
          atClient: mockAtClient,
          params: mockParams,
        );

        /// Expect that the namespace is set in the preferences
        verify(() => mockAtClient.getPreferences()).called(1);
        verify(() => mockParams.device).called(1);
        verify(() => mockAtClient.setPreferences(any())).called(1);

        /// Expect that the logger is configured correctly
        expect(sshnpCore.logger.logger.level, Level.INFO);
        expect(AtSignLogger.root_level, 'info');
      }); // test verbose=true
    }); // group Constructor

    group('Initialization', () {
      setUp(() {});
      test('AsyncInitialization', () async {
        whenConstructor();

        final sshnpCore = StubbedSshnp(
          atClient: mockAtClient,
          params: mockParams,
          sshnpdChannel: mockSshnpdChannel,
          srvdChannel: mockSrvdChannel,
        );

        /// Setup stubs for the mocks that are part of [MockAsyncInitializationMixin]
        sshnpCore.stubAsyncInitialization(
          stubbedCallInitialization: stubbedCallInitialization,
          stubbedCompleteInitialization: stubbedCompleteInitialization,
          stubbedInitialize: stubbedInitialize,
        );

        whenInitialization(identityKeyPair: sshnpCore.identityKeyPair);

        verifyNever(() => stubbedCallInitialization());
        verifyNever(() => stubbedInitialize());
        verifyNever(() => stubbedCompleteInitialization());

        await expectLater(sshnpCore.callInitialization(), completes);

        /// Using verify in order to guarantee that init cycle is correct
        /// Some of the middle steps may be valid in another, but this tests
        /// against the current implementation's order
        verifyInOrder([
          () => stubbedCallInitialization(),
          () => stubbedInitialize(),
          () => mockSshnpdChannel.callInitialization(),
          () => mockSshnpdChannel.resolveRemoteUsername(),
          () => mockSshnpdChannel.resolveTunnelUsername(
              remoteUsername: 'myRemoteUsername'),
          () => mockSshnpdChannel
              .sharePublicKeyIfRequired(sshnpCore.identityKeyPair),
          () => mockSrvdChannel.callInitialization(),
          () => stubbedCompleteInitialization(),
        ]);

        /// Ensure that no initialization steps are called twice
        verifyNever(() => stubbedCallInitialization());
        verifyNever(() => stubbedInitialize());
        verifyNever(() => mockSshnpdChannel.callInitialization());
        verifyNever(() => mockSshnpdChannel.resolveRemoteUsername());
        verifyNever(() => mockSshnpdChannel.resolveTunnelUsername(
            remoteUsername: 'myRemoteUsername'));
        verifyNever(() => mockSshnpdChannel
            .sharePublicKeyIfRequired(sshnpCore.identityKeyPair));
        verifyNever(() => mockSrvdChannel.callInitialization());
        verifyNever(() => stubbedCompleteInitialization());

        /// Ensure [initialize()] is not ran a second time if we call
        /// [callInitialization()] a second time
        await expectLater(sshnpCore.callInitialization(), completes);
        verify(() => stubbedCallInitialization()).called(1);
        verifyNever(() => stubbedInitialize());
        verifyNever(() => stubbedCompleteInitialization());
        verifyNever(() => mockSrvdChannel.callInitialization());
      });
      test('tunnelUsername not supplied', () async {
        final params = SshnpParams(
            clientAtSign: '@client',
            sshnpdAtSign: '@daemon',
            srvdAtSign: '@srvd',
            remoteUsername: 'alice');
        final channel = SshnpdDefaultChannel(
            atClient: mockAtClient,
            params: params,
            sessionId: 'test_tunnelUsername_not_supplied',
            namespace: 'test');
        final remoteUsername = await channel.resolveRemoteUsername();
        expect(remoteUsername, 'alice');
        expect(
            await channel.resolveTunnelUsername(remoteUsername: remoteUsername),
            'alice');
      });
      test('tunnelUsername supplied', () async {
        final params = SshnpParams(
            clientAtSign: '@client',
            sshnpdAtSign: '@daemon',
            srvdAtSign: '@srvd',
            remoteUsername: 'alice',
            tunnelUsername: 'bob');
        final channel = SshnpdDefaultChannel(
            atClient: mockAtClient,
            params: params,
            sessionId: 'test_tunnelUsername_supplied',
            namespace: 'test');
        final remoteUsername = await channel.resolveRemoteUsername();
        expect(remoteUsername, 'alice');
        expect(
            await channel.resolveTunnelUsername(remoteUsername: remoteUsername),
            'bob');
      });
    }); // group Initialization
  }); // group SshnpCore

  group('A group of tests related to sshnp', () {
    test('A test to verify list devices in sshnp', () async {
      registerFallbackValue(FakeScanVerbBuilder());
      registerFallbackValue(FakeAtKey());
      registerFallbackValue(FakeNotificationParams());

      MockAtClient mockAtClient = MockAtClient();
      RemoteSecondary mockRemoteSecondary = MockRemoteSecondary();
      NotificationService mockNotificationService = MockNotificationService();

      when(() => mockAtClient.getRemoteSecondary())
          .thenAnswer((_) => mockRemoteSecondary);
      when(() => mockAtClient.notificationService)
          .thenAnswer((_) => mockNotificationService);
      when(() => mockRemoteSecondary.executeVerb(any(
          that:
              FakeScanVerbBuilderMatcher()))).thenAnswer((_) => Future.value(
          'data:["device_info.active.sshnp@alice_device","device_info.inactive.sshnp@alice_device"]'));

      // StreamController to add the mock notification responses from SSHNPD.
      StreamController<AtNotification> streamController = StreamController();
      // Adding a 2-second delay to set the device as the active device.
      // First, the list of devices are fetched using AtClient.get("device_info.local.sshnp@<device_atsign>").
      // Then, a heartbeat is sent to each device to check if it's active.
      // The 2-second delay ensures notification response is sent after AtClient.get is invoked.
      Future.delayed(Duration(seconds: 2), () {
        streamController.add(AtNotification(
            '123',
            '@alice:heartbeat.active.sshnp@alice_device',
            '@alice_device',
            '@alice',
            DateTime.now().millisecondsSinceEpoch,
            'key',
            false)
          ..value =
              '{"devicename":"active","version":"5.3.0","corePackageVersion":"6.1.0","supportedFeatures":{"srAuth":true,"srE2ee":true,"acceptsPublicKeys":true,"supportsPortChoice":true,"adjustableTimeout":true},"allowedServices":["localhost:22","localhost:3389"]}');
      });
      when(() => mockNotificationService.subscribe(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'))).thenAnswer((_) {
        return streamController.stream;
      });

      when(() => mockAtClient.get(any(that: FakeAtKeyMatcher()),
              getRequestOptions: any(named: 'getRequestOptions')))
          .thenAnswer((Invocation invocation) {
        String deviceName;
        (invocation.positionalArguments[0].key.contains('inactive'))
            ? deviceName = 'inactive'
            : deviceName = 'active';
        String value =
            '{"devicename":"$deviceName","version":"5.3.0","corePackageVersion":"6.1.0","supportedFeatures":{"srAuth":true,"srE2ee":true,"acceptsPublicKeys":true,"supportsPortChoice":true,"adjustableTimeout":true},"allowedServices":["localhost:22","localhost:3389"]}';
        return Future.value(AtValue()..value = value);
      });

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

      SshnpParams sshnpParams = SshnpParams(
          clientAtSign: '@alice',
          sshnpdAtSign: '@alice_device',
          srvdAtSign: '@srvd');
      AtSshKeyPair atSshKeyPair =
          await DartSshKeyUtil().generateKeyPair(identifier: 'my-test');
      StreamController<String> testStreamController = StreamController();
      Sshnp sshnp = SshnpDartPureImpl(
          atClient: mockAtClient,
          params: sshnpParams,
          identityKeyPair: atSshKeyPair,
          logStream: testStreamController.stream);

      SshnpDeviceList sshnpDeviceList = await sshnp.listDevices();
      expect(sshnpDeviceList.info.length, 2);
      expect(sshnpDeviceList.activeDevices, ['active']);
      expect(sshnpDeviceList.inactiveDevices, ['inactive']);
    });

    test('A test to verify notifying ssh request to sshnpd', () async {
      registerFallbackValue(FakeNotificationParams());
      AtEncryptionKeyPair atEncryptionKeyPair =
          AtChopsUtil.generateAtEncryptionKeyPair();

      MockAtClient mockAtClient = MockAtClient();
      MockNotificationService mockNotificationService =
          MockNotificationService();

      when(() => mockAtClient.atChops).thenAnswer(
          (_) => AtChopsImpl(AtChopsKeys.create(atEncryptionKeyPair, null)));

      when(() => mockAtClient.notificationService)
          .thenAnswer((_) => mockNotificationService);

      when(() =>
              mockNotificationService.notify(any(),
                  checkForFinalDeliveryStatus:
                      any(named: 'checkForFinalDeliveryStatus'),
                  waitForFinalDeliveryStatus:
                      any(named: 'waitForFinalDeliveryStatus'),
                  onSuccess: any(named: 'onSuccess'),
                  onError: any(named: 'onError'),
                  onSentToSecondary: any(named: 'onSentToSecondary')))
          .thenAnswer(expectAsync1((Invocation invocation) async {
        // Assert when the notification response belongs to "ssh_request"
        if (invocation.positionalArguments[0].atKey.key
            .contains('ssh_request')) {
          expect(invocation.positionalArguments[0].atKey.toString(),
              '@alice_device:ssh_request.default.sshnp@alice');
          print(invocation.positionalArguments[0].value);
          Map sshRequestResponse =
              jsonDecode(invocation.positionalArguments[0].value);
          expect(sshRequestResponse['payload']['direct'], true);
          expect(
              sshRequestResponse['payload']['sessionId'].toString().isNotEmpty,
              true);
          expect(sshRequestResponse['payload']['host'], '127.0.0.1');
          expect(sshRequestResponse['payload']['port'], 98879);
          expect(sshRequestResponse['payload']['authenticateToRvd'], true);
          expect(sshRequestResponse['payload']['rvdNonce'], 'rvd_dummy_nonce');
          expect(sshRequestResponse['payload']['encryptRvdTraffic'], true);
          expect(sshRequestResponse['payload']['clientEphemeralPK'].isNotEmpty,
              true);
          expect(sshRequestResponse['signature'].isNotEmpty, true);
          expect(sshRequestResponse['hashingAlgo'].isNotEmpty, true);
          expect(sshRequestResponse['signingAlgo'].isNotEmpty, true);
        }

        return Future.value(NotificationResult()
          ..notificationStatusEnum = NotificationStatusEnum.delivered);
      }, count: 2));

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

      SshnpParams sshnpParams = SshnpParams(
          clientAtSign: '@alice',
          sshnpdAtSign: '@alice_device',
          srvdAtSign: '@srvd');
      AtSshKeyPair atSshKeyPair =
          await DartSshKeyUtil().generateKeyPair(identifier: 'my-test');
      StreamController<String> testStreamController = StreamController();
      SshnpDartPureImpl sshnp = SshnpDartPureImpl(
          atClient: mockAtClient,
          params: sshnpParams,
          identityKeyPair: atSshKeyPair,
          logStream: testStreamController.stream);

      // Initialize srvd, to fetch the host and port from the srvd -
      // Here returning a mocked response from a stream controller.
      await sshnp.srvdChannel.initialize();
      await sshnp.sendSshRequestToSshnpd();
    });
  });
}

class FakeScanVerbBuilderMatcher extends Matcher {
  @override
  Description describe(Description description) {
    return description;
  }

  @override
  bool matches(item, Map matchState) {
    return true;
  }
}

class FakeAtKeyMatcher extends Matcher {
  @override
  Description describe(Description description) {
    return description;
  }

  @override
  bool matches(item, Map matchState) {
    if (item is AtKey) {
      return true;
    }
    return false;
  }
}
