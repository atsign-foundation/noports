import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../../sshnp_mocks.dart';

void main() {
  group('SshrvdExecChannel', () {
    late MockAtClient mockAtClient;
    late MockSshnpParams mockSshnpParams;
    late String sessionId;

    setUp(() {
      mockAtClient = MockAtClient();
      mockSshnpParams = MockSshnpParams();
      sessionId = Uuid().v4();
    });
    test('public API', () {
      expect(
        SshrvdExecChannel(
          atClient: mockAtClient,
          params: mockSshnpParams,
          sessionId: sessionId,
        ),
        isA<SshrvdChannel<Process>>(),
      );
    });
  }); // group SshrvdDartChannel
}
