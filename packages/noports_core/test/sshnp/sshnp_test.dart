import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import 'sshnp_mocks.dart';

class StubbedSshnp extends Mock implements Sshnp {}

class MySshnpResult extends SshnpResult {}

void main() {
  group('Sshnp', () {
    late final StubbedSshnp stubbedSshnp;
    late final MockAtClient mockAtClient;
    late final MockSshnpParams mockSshnpParams;
    late final MySshnpResult mySshnpResult;
    late final SshnpDeviceList sshnpDeviceList;

    setUp(() {
      stubbedSshnp = StubbedSshnp();
      mockAtClient = MockAtClient();
      mockSshnpParams = MockSshnpParams();
      mySshnpResult = MySshnpResult();
      sshnpDeviceList = SshnpDeviceList();
    });

    test('public API test', () async {
      /// Just test that the public members are there,
      /// implementation specific factories will be tested as part of the
      /// implementation specific tests.
      when(() => stubbedSshnp.atClient).thenReturn(mockAtClient);
      when(() => stubbedSshnp.params).thenReturn(mockSshnpParams);
      when(() => stubbedSshnp.run()).thenAnswer((_) async => mySshnpResult);
      when(() => stubbedSshnp.listDevices())
          .thenAnswer((_) async => sshnpDeviceList);

      expect(stubbedSshnp.atClient, mockAtClient);
      expect(stubbedSshnp.params, mockSshnpParams);
      await expectLater(await stubbedSshnp.run(), mySshnpResult);
      await expectLater(await stubbedSshnp.listDevices(), sshnpDeviceList);
    });
  }); // group Sshnp
}
