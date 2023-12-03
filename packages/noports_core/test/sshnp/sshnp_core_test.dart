import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'sshnp_mocks.dart';
import 'sshnp_core_mocks.dart';

void main() {
  group('SshnpCore', () {
    /// Creation mocks
    late AtClient mockAtClient;
    late SshnpParams mockParams;
    late SshnpdChannel mockSshnpdChannel;
    late SshrvdChannel mockSshrvdChannel;

    /// Initialization stubs
    late FunctionStub<void> stubbedCallInitialization;
    late FunctionStub<void> stubbedInitialize;
    late FunctionStub<void> stubbedCompleteInitialization;

    setUp(() {
      /// Creation
      mockAtClient = MockAtClient();
      mockParams = MockSshnpParams();
      mockSshnpdChannel = MockSshnpdChannel();
      mockSshrvdChannel = MockSshrvdChannel();
      registerFallbackValue(AtClientPreference());

      /// Initialization
      stubbedCallInitialization = FunctionStub();
      stubbedInitialize = FunctionStub();
      stubbedCompleteInitialization = FunctionStub();
    });

    /// When declaration setup for the constructor of [StubbedSshnp]
    whenConstructor({bool verbose = false}) {
      when(() => mockParams.device).thenReturn('mydevice');
      when(() => mockParams.localPort).thenReturn(0);
      when(() => mockParams.verbose).thenReturn(verbose);
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
      when(() => mockSshrvdChannel.callInitialization())
          .thenAnswer((_) async {});
    }

    group('Constructor', () {
      test('verbose=false', () {
        whenConstructor(verbose: false);

        final sshnpCore = StubbedSshnp(
            atClient: mockAtClient,
            params: mockParams,
            userKeyPairIdentifier: null);

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
            userKeyPairIdentifier: null);

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
          userKeyPairIdentifier: null,
          sshnpdChannel: mockSshnpdChannel,
          sshrvdChannel: mockSshrvdChannel,
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
          () => mockSshrvdChannel.callInitialization(),
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
        verifyNever(() => mockSshrvdChannel.callInitialization());
        verifyNever(() => stubbedCompleteInitialization());

        /// Ensure [initialize()] is not ran a second time if we call
        /// [callInitialization()] a second time
        await expectLater(sshnpCore.callInitialization(), completes);
        verify(() => stubbedCallInitialization()).called(1);
        verifyNever(() => stubbedInitialize());
        verifyNever(() => stubbedCompleteInitialization());
        verifyNever(() => mockSshrvdChannel.callInitialization());
      });
      test('tunnelUsername not supplied', () async {
        final params = SshnpParams(
            clientAtSign: '@client',
            sshnpdAtSign: '@daemon',
            host: 'foo.bar.test',
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
            host: 'foo.bar.test',
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
}
