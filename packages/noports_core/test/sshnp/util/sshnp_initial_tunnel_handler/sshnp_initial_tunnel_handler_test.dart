import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

class StubbedSshnpSshSessionHandler extends Mock
    with SshnpSshSessionHandler<String> {}

void main() {
  group('SshnpSshSessionHandler', () {
    late final StubbedSshnpSshSessionHandler handler;
    setUp(() {
      handler = StubbedSshnpSshSessionHandler();
    });
    test('public API', () async {
      when(() => handler.startInitialTunnelSession(keyPairIdentifier: 'asdf'))
          .thenAnswer((invocation) async => 'Called');

      await expectLater(
        await handler.startInitialTunnelSession(keyPairIdentifier: 'asdf'),
        'Called',
      );
    }); // test public API
  }); // group SshnpSshSessionHandler
}
