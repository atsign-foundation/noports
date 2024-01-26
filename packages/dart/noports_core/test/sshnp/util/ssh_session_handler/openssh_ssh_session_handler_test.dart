import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import '../../sshnp_mocks.dart';
import 'openssh_ssh_session_handler_mocks.dart';

void main() {
  group('SshnpOpensshSshSessionHandler', () {
    late MockAtClient mockAtClient;
    late MockSshnpParams mockParams;
    late MockSshnpdChannel mockSshnpChannel;
    late MockSrvdChannel mockSrvdChannel;
    late StubbedSshnp stubbedSshnp;

    setUp(() {
      mockAtClient = MockAtClient();
      mockParams = MockSshnpParams();
      mockSshnpChannel = MockSshnpdChannel();
      mockSrvdChannel = MockSrvdChannel();

      // Mocked SshnpCore Constructor calls
      registerFallbackValue(AtClientPreference());
      when(() => mockParams.device).thenReturn('mydevice');
      when(() => mockParams.localPort).thenReturn(0);
      when(() => mockParams.verbose).thenReturn(false);
      when(() => mockAtClient.getPreferences()).thenReturn(null);
      when(() => mockAtClient.setPreferences(any())).thenReturn(null);

      stubbedSshnp = StubbedSshnp(
        atClient: mockAtClient,
        params: mockParams,
        sshnpdChannel: mockSshnpChannel,
        srvdChannel: mockSrvdChannel,
      );

      // Mocked SshnpCore Initialization calls
      // TODO srvd channel mock calls
      // TODO sshnpd channel mock calls
    });

    test('implements SshnpSshSessionHandler<Process?>', () {
      expect(stubbedSshnp, isA<SshSessionHandler<Process?>>());
    }); // test public API
    test('startInitialTunnel', () {}); // test startInitialTunnel
  }); // group SshnpOpensshSshSessionHandler
}
