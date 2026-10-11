import 'package:at_client/at_client.dart';
import 'package:noports_core/admin.dart';
import 'package:test/test.dart';

void main() {
  group('Given npp_atserver rules', () {
    test(
        "a daemon has rules when a group's daemon atSigns list it, and"
        ' otherwise not', () {
      final service = PolicyServiceInMem();
      service.groups['1'] = UserGroup(
        id: '1',
        name: 'engineers',
        description: '',
        userAtSigns: ['@alice'],
        daemonAtSigns: ['@daemon'],
        devices: [],
        deviceGroups: [],
      );

      expect(service.hasRulesFor('@daemon'.toAtsign()), isTrue);
      expect(service.hasRulesFor('@other'.toAtsign()), isFalse);
    });
  });
}
