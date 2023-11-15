import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../../sshnp_mocks.dart';
import 'sshrvd_channel_mocks.dart';

void main() {
  group('SshrvdChannel', () {
    late SshrvGeneratorStub sshrvGeneratorStub;
    late MockAtClient mockAtClient;
    late MockSshnpParams mockParams;
    late String sessionId;
    late StubbedSshrvdChannel stubbedSshrvdChannel;

    setUp(() {
      sshrvGeneratorStub = SshrvGeneratorStub();
      mockAtClient = MockAtClient();
      mockParams = MockSshnpParams();
      sessionId = Uuid().v4();

      stubbedSshrvdChannel = StubbedSshrvdChannel(
        atClient: mockAtClient,
        params: mockParams,
        sessionId: sessionId,
        sshrvGenerator: sshrvGeneratorStub,
      );
    });

    
  }); // group SshrvdChannel
}
