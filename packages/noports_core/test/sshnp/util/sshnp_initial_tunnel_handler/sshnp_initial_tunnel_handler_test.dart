import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

class StubbedSshnpInitialTunnelHandler extends Mock
    with SshnpInitialTunnelHandler<String> {}

void main() {
  group('SshnpInitialTunnelHandler', () {
    late final StubbedSshnpInitialTunnelHandler handler;
    setUp(() {
      handler = StubbedSshnpInitialTunnelHandler();
    });
    test('public API', () async {
      when(() => handler.startInitialTunnel(identifier: 'asdf'))
          .thenAnswer((invocation) async => 'Called');

      await expectLater(
        await handler.startInitialTunnel(identifier: 'asdf'),
        'Called',
      );
    }); // test public API
  }); // group SshnpInitialTunnelHandler
}
