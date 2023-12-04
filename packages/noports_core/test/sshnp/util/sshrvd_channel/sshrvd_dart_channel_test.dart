import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../../sshnp_mocks.dart';

void main() {
  group('SshrvdDartChannel', () {
    late MockAtClient mockAtClient;
    late MockSshnpParams mockSshnpParams;
    late String sessionId;

    setUp(() {
      mockAtClient = MockAtClient();
      mockSshnpParams = MockSshnpParams();
      when(() => mockSshnpParams.verbose).thenReturn(false);
      sessionId = Uuid().v4();
    });
    test('public API', () {
      expect(
        SshrvdDartChannel(
          atClient: mockAtClient,
          params: mockSshnpParams,
          sessionId: sessionId,
        ),
        isA<SshrvdChannel<SocketConnector>>(),
      );
    });
  }); // group SshrvdDartChannel
}
