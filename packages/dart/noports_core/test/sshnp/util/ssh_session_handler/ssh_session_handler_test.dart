import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

class StubbedSshnpSshSessionHandler extends Mock
    with SshSessionHandler<String> {}

void main() {
  group('SshnpSshSessionHandler', () {
    late final StubbedSshnpSshSessionHandler handler;
    setUp(() {
      handler = StubbedSshnpSshSessionHandler();
    });
    test('public API', () async {
      when(() => handler.startInitialTunnelSession(
              ephemeralKeyPairIdentifier: 'asdf'))
          .thenAnswer((invocation) async => 'Called');

      await expectLater(
        await handler.startInitialTunnelSession(
            ephemeralKeyPairIdentifier: 'asdf'),
        'Called',
      );
    }); // test public API
  }); // group SshnpSshSessionHandler
}
