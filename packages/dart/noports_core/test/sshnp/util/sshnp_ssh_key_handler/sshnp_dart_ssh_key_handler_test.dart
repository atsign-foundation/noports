import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import 'sshnp_ssh_key_handler_mocks.dart';

void main() {
  group('SshnpDartSshKeyHandler', () {
    late MockSshnpDartSshKeyHandler keyHandler;
    late MockAtSshKeyPair mockKeyPair;

    setUp(() {
      keyHandler = MockSshnpDartSshKeyHandler();
      mockKeyPair = MockAtSshKeyPair();
    });

    test('public API', () {
      /// The Dart key handler requires that there is a setter for
      /// identityKeyPair, in addition to a getter
      keyHandler.identityKeyPair = mockKeyPair;
      expect(keyHandler.identityKeyPair, mockKeyPair);

      expect(MockSshnpDartSshKeyHandler(), isA<SshnpKeyHandler>());
    }); // test initialization
  }); // group SshnpDartKeyHandler
}
