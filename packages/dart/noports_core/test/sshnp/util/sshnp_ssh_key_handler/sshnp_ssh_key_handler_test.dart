import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import 'sshnp_ssh_key_handler_mocks.dart';

void main() {
  group('SshnpKeyHandler', () {
    late MockSshnpKeyHandler mockKeyHandler;
    late MockAtSshKeyUtil mockKeyUtil;
    late MockAtSshKeyPair mockKeyPair;

    setUp(() {
      mockKeyHandler = MockSshnpKeyHandler();
      mockKeyUtil = MockAtSshKeyUtil();
      mockKeyPair = MockAtSshKeyPair();
    });

    test('public API', () {
      when(() => mockKeyHandler.keyUtil).thenReturn(mockKeyUtil);
      when(() => mockKeyHandler.identityKeyPair).thenReturn(mockKeyPair);

      expect(mockKeyHandler.keyUtil, isA<AtSshKeyUtil>());
      expect(mockKeyHandler.identityKeyPair, isA<AtSshKeyPair?>());
    }); // test public API
  }); // group SshnpKeyHandler
}
