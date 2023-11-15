import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'sshnp_core_mocks.dart';

void main() {
  group('SshnpCore', () {
    /// Creation mocks
    late AtClient mockAtClient;
    late SshnpParams mockParams;
    late SshnpdChannel mockSshnpdChannel;
    late SshrvdChannel mockSshrvdChannel;

    /// Initialization stubs
    late FunctionStub stubbedCallInitialization;
    late FunctionStub stubbedInitialize;
    late FunctionStub stubbedCompleteInitialization;

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

    /// When declaration setup for the constructor of [StubbedSshnpCore]
    whenConstructor({bool verbose = false}) {
      when(() => mockParams.device).thenReturn('mydevice');
      when(() => mockParams.localPort).thenReturn(0);
      when(() => mockParams.verbose).thenReturn(verbose);
      when(() => mockAtClient.getPreferences()).thenReturn(null);
      when(() => mockAtClient.setPreferences(any())).thenReturn(null);
    }

    /// When declaration setup for the initialization of [StubbedSshnpCore]
    whenInitialization({AtSshKeyPair? identityKeyPair}) {
      when(() => stubbedCallInitialization.call()).thenAnswer((_) async {});
      when(() => stubbedInitialize.call()).thenAnswer((_) async {});
      when(() => stubbedCompleteInitialization.call()).thenReturn(null);

      when(() => mockSshnpdChannel.callInitialization())
          .thenAnswer((_) async {});
      when(() => mockSshnpdChannel.resolveRemoteUsername())
          .thenAnswer((_) async => 'myRemoteUsername');
      when(() => mockSshnpdChannel.sharePublicKeyIfRequired(
          identityKeyPair ?? any())).thenAnswer((_) async {});
      when(() => mockSshrvdChannel.callInitialization())
          .thenAnswer((_) async {});
    }

    group('Constructor', () {
      test('verbose=false', () {
        whenConstructor(verbose: false);

        final sshnpCore =
            StubbedSshnpCore(atClient: mockAtClient, params: mockParams);

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

        final sshnpCore =
            StubbedSshnpCore(atClient: mockAtClient, params: mockParams);

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

        final sshnpCore = StubbedSshnpCore(
          atClient: mockAtClient,
          params: mockParams,
          sshnpdChannel: mockSshnpdChannel,
          sshrvdChannel: mockSshrvdChannel,
        );

        /// Setup stubs for the mocks that are part of [MockAsyncInitializationMixin]
        sshnpCore.stubAsyncInitialization(
          mockCallInitialization: stubbedCallInitialization,
          mockCompleteInitialization: stubbedCompleteInitialization,
          mockInitialize: stubbedInitialize,
        );

        whenInitialization(identityKeyPair: sshnpCore.identityKeyPair);

        verifyNever(() => stubbedCallInitialization.call());
        verifyNever(() => stubbedInitialize.call());
        verifyNever(() => stubbedCompleteInitialization.call());

        await expectLater(sshnpCore.callInitialization(), completes);

        /// Using verify in order to guarantee that init cycle is correct
        /// Some of the middle steps may be valid in another, but this tests
        /// against the current implementation's order
        verifyInOrder([
          () => stubbedCallInitialization.call(),
          () => stubbedInitialize.call(),
          () => mockSshnpdChannel.callInitialization(),
          () => mockSshnpdChannel.resolveRemoteUsername(),
          () => mockSshnpdChannel
              .sharePublicKeyIfRequired(sshnpCore.identityKeyPair),
          () => mockSshrvdChannel.callInitialization(),
          () => stubbedCompleteInitialization.call(),
        ]);

        /// Ensure that no initialization steps are called twice
        verifyNever(() => stubbedCallInitialization.call());
        verifyNever(() => stubbedInitialize.call());
        verifyNever(() => mockSshnpdChannel.callInitialization());
        verifyNever(() => mockSshnpdChannel.resolveRemoteUsername());
        verifyNever(() => mockSshnpdChannel
            .sharePublicKeyIfRequired(sshnpCore.identityKeyPair));
        verifyNever(() => mockSshrvdChannel.callInitialization());
        verifyNever(() => stubbedCompleteInitialization.call());

        /// Ensure [initialize()] is not ran a second time if we call
        /// [callInitialization()] a second time
        await expectLater(sshnpCore.callInitialization(), completes);
        verify(() => stubbedCallInitialization.call()).called(1);
        verifyNever(() => stubbedInitialize.call());
        verifyNever(() => stubbedCompleteInitialization.call());
        verifyNever(() => mockSshrvdChannel.callInitialization());
      });
    }); // group Initialization
  }); // group SshnpCore
}
