import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/platform/device_names.dart';
import 'package:noports_core/utils.dart' show invalidDeviceName;

void main() {
  test('accepts exactly what sshnpd accepts', () {
    for (final name in [
      'default',
      'my-device',
      'pc_01',
      '0abc',
      'ab',
      'a' * 36,
    ]) {
      expect(DeviceNames.isValid(name), isTrue, reason: name);
      expect(invalidDeviceName(name), isFalse, reason: name);
    }
    for (final name in ['a', '-pc', 'My-PC', 'pc 1', 'a' * 37, 'é', '']) {
      expect(DeviceNames.isValid(name), isFalse, reason: name);
    }
  });

  test('hostname becomes a valid name', () {
    expect(DeviceNames.fromHostname('Colins-MacBook-Pro.local'), 'colins-macbook-pro');
    expect(DeviceNames.fromHostname('srv01.example.com'), 'srv01');
    expect(DeviceNames.fromHostname('-weird'), 'weird');
    expect(DeviceNames.fromHostname('x'), 'default');
    expect(DeviceNames.fromHostname('a' * 50), 'a' * 36);
    expect(DeviceNames.fromHostname('Désk top'), 'd_sk_top');
    expect(DeviceNames.isValid(DeviceNames.fromHostname()), isTrue);
  });
}
