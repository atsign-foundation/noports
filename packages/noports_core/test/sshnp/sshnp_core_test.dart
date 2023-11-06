import 'package:at_client/at_client.dart';
import 'package:noports_core/sshnp_params.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

class MockAtClient extends Mock implements AtClient {}

class MockSshnpParams extends Mock implements SshnpParams {}

void main() {
  group('Sshnp Core', () {
    late AtClient atClient;
    late SshnpParams params;

    setUp(() {
      atClient = MockAtClient();
      params = MockSshnpParams();
      registerFallbackValue(AtClientPreference());
    });

    test('Constructor - expect that the namespace is set based on params', () {
      verifyNever(() => atClient.getPreferences());
      verifyNever(() => params.device);
      verifyNever(() => atClient.setPreferences(any()));

      when(() => atClient.getPreferences()).thenReturn(null);
      when(() => params.device).thenReturn('mydevice');
      when(() => atClient.setPreferences(any())).thenReturn(null);

// TODO write a new MYSshnpCore class
      // final sshnpCore = MySshnpCore(atClient: atClient, params: params);

      // verify(() => atClient.getPreferences()).called(1);
      // verify(() => params.device).called(1);
      // verify(() => atClient.setPreferences(any())).called(1);
    });
  });
}
