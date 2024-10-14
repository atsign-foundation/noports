import 'package:at_client/at_client.dart';
import 'package:noports_core/src/common/features.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sshnp_mocks.dart';
import 'sshnp_ssh_key_handler_mocks.dart';

void main() {
  group('SshnpLocalSshKeyHandler', () {
    late MockAtClient mockAtClient;
    late MockSshnpParams mockParams;
    late MockLocalSshKeyUtil keyUtil;
    late MockAtSshKeyPair keyPair;

    late MockSshnpdChannel mockSshnpdChannel;
    late MockSrvdChannel mockSrvdChannel;

    setUp(() {
      mockAtClient = MockAtClient();
      mockParams = MockSshnpParams();
      keyUtil = MockLocalSshKeyUtil();
      keyPair = MockAtSshKeyPair();

      mockSshnpdChannel = MockSshnpdChannel();
      mockSrvdChannel = MockSrvdChannel();
      registerFallbackValue(AtClientPreference());
    });

    whenConstructor() {
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');
      when(() => mockParams.device).thenReturn('mydevice');
      when(() => mockParams.localPort).thenReturn(0);
      when(() => mockParams.verbose).thenReturn(false);
      when(() => mockParams.authenticateDeviceToRvd).thenReturn(true);
      when(() => mockParams.authenticateClientToRvd).thenReturn(true);
      when(() => mockParams.encryptRvdTraffic).thenReturn(true);
      when(() => mockParams.sendSshPublicKey).thenReturn(false);
      when(() => mockAtClient.getPreferences()).thenReturn(null);
      when(() => mockAtClient.setPreferences(any())).thenReturn(null);
    }

    whenInitialization({AtSshKeyPair? identityKeyPair}) {
      when(() => mockSshnpdChannel.callInitialization())
          .thenAnswer((_) async {});
      when(() => mockSshnpdChannel.resolveRemoteUsername())
          .thenAnswer((_) async => 'myRemoteUsername');
      when(() => mockSshnpdChannel.resolveTunnelUsername(
              remoteUsername: any(named: 'remoteUsername')))
          .thenAnswer((_) async => 'myTunnelUsername');
      when(() => mockSshnpdChannel.sharePublicKeyIfRequired(identityKeyPair))
          .thenAnswer((_) async {});
      when(() => mockSshnpdChannel.featureCheck(any(),any())).thenAnswer((_) async {
        return DaemonFeature.values.map((f) => (f, true, 'mocked')).toList();
      });
      when(() => mockSrvdChannel.callInitialization()).thenAnswer((_) async {});
    }

    test('public API', () {
      whenConstructor();
      final sshnp = StubbedSshnp(
        atClient: mockAtClient,
        params: mockParams,
      );
      expect(sshnp, isA<SshnpKeyHandler>());
    }); // test public API

    test('initialization', () async {
      whenConstructor();

      final sshnp = StubbedSshnp(
        atClient: mockAtClient,
        params: mockParams,
        sshKeyUtil: keyUtil,
        sshnpdChannel: mockSshnpdChannel,
        srvdChannel: mockSrvdChannel,
      );

      whenInitialization(identityKeyPair: keyPair);
      final identityFile = '.ssh/asdf';
      when(() => keyUtil.isValidPlatform).thenReturn(true);
      when(() => mockParams.identityFile).thenReturn(identityFile);
      when(() => keyUtil.getKeyPair(identifier: identityFile))
          .thenAnswer((_) async => keyPair);

      /// normally we would call [callInitialization()] but it's fine to call
      /// initialize directly for testing purposes, since we avoid weird
      /// lifecycle issues that could be caused by mocking
      await sshnp.initialize();

      /// We don't care about [SshnpCore] initialization here, we only care that
      /// the [keyPair] is set correctly, since [SshnpCore] is tested elsewhere
      expect(sshnp.identityKeyPair, keyPair);
    }); // test initialization

    test('initialization - no identityFile', () async {
      whenConstructor();

      final sshnp = StubbedSshnp(
        atClient: mockAtClient,
        params: mockParams,
        sshKeyUtil: keyUtil,
        sshnpdChannel: mockSshnpdChannel,
        srvdChannel: mockSrvdChannel,
      );

      whenInitialization(identityKeyPair: keyPair);
      when(() => keyUtil.isValidPlatform).thenReturn(true);
      when(() => mockParams.identityFile).thenReturn(null);
      when(() => mockSshnpdChannel.sharePublicKeyIfRequired(null))
          .thenAnswer((_) async {});
      when(() => keyUtil.getKeyPair(identifier: '.ssh/asdf'))
          .thenAnswer((_) async => keyPair);

      /// normally we would call [callInitialization()] but it's fine to call
      /// initialize directly for testing purposes, since we avoid weird
      /// lifecycle issues that could be caused by mocking
      await sshnp.initialize();

      /// We don't care about [SshnpCore] initialization here, we only care that
      /// the [keyPair] is set correctly, since [SshnpCore] is tested elsewhere
      expect(sshnp.identityKeyPair, null);
    }); // test initialization - no identityFile

    test('initialization - invalid platform', () {
      whenConstructor();

      final sshnp = StubbedSshnp(
        atClient: mockAtClient,
        params: mockParams,
        sshKeyUtil: keyUtil,
        sshnpdChannel: mockSshnpdChannel,
        srvdChannel: mockSrvdChannel,
      );

      whenInitialization();
      when(() => keyUtil.isValidPlatform).thenReturn(false);
      expect(sshnp.initialize(), throwsA(isA<SshnpError>()));
    });
  }); // group SshnpLocalSshKeyHandler
}
