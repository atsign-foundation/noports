import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

class MockAtClient extends Mock implements AtClient {}

class MockSshnpParams extends Mock implements SshnpParams {}

class MySshnpCore extends SshnpCore {
  MySshnpCore({
    required super.atClient,
    required super.params,
  });

  @override
  AtSshKeyPair? get identityKeyPair => throw UnimplementedError();

  @override
  AtSshKeyUtil get keyUtil => throw UnimplementedError();

  @override
  Future<SshnpResult> run() => throw UnimplementedError();

  @override
  SshnpdChannel get sshnpdChannel => throw UnimplementedError();

  @override
  SshrvdChannel? get sshrvdChannel => throw UnimplementedError();
}

void main() {
  group('Sshnp Core', () {
    late AtClient mockAtClient;
    late SshnpParams mockParams;

    setUp(() {
      mockAtClient = MockAtClient();
      mockParams = MockSshnpParams();
      registerFallbackValue(AtClientPreference());
    });

    test('Constructor', () {
      when(() => mockParams.device).thenReturn('mydevice');
      when(() => mockParams.localPort).thenReturn(0);
      when(() => mockParams.verbose).thenReturn(false);

      when(() => mockAtClient.getPreferences()).thenReturn(null);
      when(() => mockAtClient.setPreferences(any())).thenReturn(null);

      final sshnpCore = MySshnpCore(atClient: mockAtClient, params: mockParams);

      /// Expect that the namespace is set in the preferences
      verify(() => mockAtClient.getPreferences()).called(1);
      verify(() => mockParams.device).called(1);
      verify(() => mockAtClient.setPreferences(any())).called(1);

      /// Expect that the logger is configured correctly
      expect(sshnpCore.logger.logger.level, Level.SHOUT);
      expect(AtSignLogger.root_level, 'info');
    });

    test('Constructor - verbose logger', () {
      when(() => mockParams.device).thenReturn('mydevice');
      when(() => mockParams.localPort).thenReturn(0);
      when(() => mockParams.verbose).thenReturn(true);

      when(() => mockAtClient.getPreferences()).thenReturn(null);
      when(() => mockAtClient.setPreferences(any())).thenReturn(null);

      final sshnpCore = MySshnpCore(atClient: mockAtClient, params: mockParams);

      /// Expect that the namespace is set in the preferences
      verify(() => mockAtClient.getPreferences()).called(1);
      verify(() => mockParams.device).called(1);
      verify(() => mockAtClient.setPreferences(any())).called(1);

      /// Expect that the logger is configured correctly
      expect(sshnpCore.logger.logger.level, Level.INFO);
      expect(AtSignLogger.root_level, 'info');
    });
  });
}
