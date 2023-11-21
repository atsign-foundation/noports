import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

void main() {
  group('SshnpDeviceList', () {
    late SshnpDeviceList deviceList;
    setUp(() => deviceList = SshnpDeviceList());
    test('public API', () {
      expect(
        deviceList.info,
        allOf(isA<Map<String, dynamic>>(), isEmpty),
      );

      expect(
        deviceList.activeDevices,
        allOf(isA<Set<String>>(), isEmpty),
      );
    }); // test public API

    test('setActive', () {
      expect(deviceList.info, isEmpty);

      deviceList.info['dev1'] = 'asdf';
      deviceList.setActive('dev1');
      expect(
        deviceList.activeDevices,
        allOf(hasLength(1), contains('dev1')),
      );

      deviceList.setActive('dev2');
      expect(
        deviceList.activeDevices,
        allOf(hasLength(1), isNot(contains('dev2'))),
      );
    });

    test('inactiveDevices', () {
      deviceList.info['dev1'] = 'asdf';
      deviceList.info['dev2'] = 'jkl;';
      deviceList.setActive('dev1');

      expect(
        deviceList.inactiveDevices,
        allOf(hasLength(1), contains('dev2')),
      );
    }); // test inactiveDevices
  }); // group SshnpDeviceList
}
