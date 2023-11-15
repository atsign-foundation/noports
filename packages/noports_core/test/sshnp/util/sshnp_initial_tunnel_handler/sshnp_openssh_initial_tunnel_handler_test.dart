import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import 'sshnp_openssh_initial_tunnel_handler_mocks.dart';

void main() {
  group('SshnpOpensshInitialTunnelHandler', () {
    late final MockAtClient mockAtClient;
    late final MockSshnpParams mockParams;
    late final MockSshnpdChannel mockSshnpChannel;
    late final MockSshrvdChannel mockSshrvdChannel;
    late final StubbedSshnp stubbedSshnp;

    setUp(() {
      mockAtClient = MockAtClient();
      mockParams = MockSshnpParams();
      mockSshnpChannel = MockSshnpdChannel();
      mockSshrvdChannel = MockSshrvdChannel();

      // Mocked SshnpCore Constructor calls
      when(() => mockParams.device).thenReturn('mydevice');
      when(() => mockParams.localPort).thenReturn(0);
      when(() => mockParams.verbose).thenReturn(false);
      when(() => mockAtClient.getPreferences()).thenReturn(null);
      when(() => mockAtClient.setPreferences(any())).thenReturn(null);

      stubbedSshnp = StubbedSshnp(
        atClient: mockAtClient,
        params: mockParams,
        sshnpdChannel: mockSshnpChannel,
        sshrvdChannel: mockSshrvdChannel,
      );

      // Mocked SshnpCore Initialization calls
      // TODO sshrvd channel mock calls
      // TODO sshnpd channel mock calls
    });

    test('implements SshnpInitialTunnelHandler<Process?>', () {
      expect(stubbedSshnp, isA<SshnpInitialTunnelHandler<Process?>>());
    }); // test public API
    test('startInitialTunnel', () {}); // test startInitialTunnel
  }); // group SshnpOpensshInitialTunnelHandler
}
