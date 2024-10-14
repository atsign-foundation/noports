import 'package:at_policy/at_policy.dart';
import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAtClient extends Mock implements AtClient {}

void main() {
  group('core create retrieve update delete', () {
    final api = PolicyAPI.inMemory(policyAtSign: '@policy');

    setUp(() async {
      expect(api.groups, isEmpty);
    });

    test('add group', () async {
      String n = 'sysadmins';
      String d = 'Description';

      UserGroup? ug = UserGroup.empty(name: n, description: d);
      await api.createUserGroup(ug);

      expect(api.groups.containsKey(ug.id), true);
      expect(api.groups[ug.id]!.name, n);
      expect(api.groups[ug.id]!.description, d);

      ug = await api.getUserGroup(ug.id!);
      expect(ug, isNotNull);
      expect(ug!.name, n);
      expect(ug.description, d);
      expect(ug.daemonAtSigns, isEmpty);
      expect(ug.devices, isEmpty);
      expect(ug.deviceGroups, isEmpty);
      expect(ug.userAtSigns, isEmpty);
    });

    test('update group', () async {
      String n1 = 'sysadmins';
      String d1 = 'Description';
      String n2 = 'some other group';
      String d2 = 'some other group description';

      var g1 = await api.createUserGroup(
        UserGroup.empty(name: n1, description: d1),
      );
      expect(api.groups.length, 1);

      var g2 = await api.createUserGroup(
        UserGroup.empty(name: n2, description: d2),
      );
      expect(api.groups.length, 2);

      g1 = (await api.getUserGroup(g1.id!))!;
      expect(g1.name, n1);
      expect(g1.description, d1);

      g2 = (await api.getUserGroup(g2.id!))!;
      expect(g2.name, n2);
      expect(g2.description, d2);

      await api.updateUserGroup(
        UserGroup.empty(
          id: g1.id,
          name: n1,
          description: 'Updated description',
        ),
      );
      expect(api.groups.length, 2);

      g1 = (await api.getUserGroup(g1.id!))!;
      expect(g1.name, n1);
      expect(g1.description, 'Updated description');

      g2 = (await api.getUserGroup(g2.id!))!;
      expect(g2.name, n2);
      expect(g2.description, d2);
    });

    test('delete group', () async {
      String n1 = 'sysadmins';
      String d1 = 'Description';
      String n2 = 'some other group';
      String d2 = 'some other group description';

      var g1 = await api.createUserGroup(
        UserGroup.empty(name: n1, description: d1),
      );
      expect(api.groups.length, 1);

      var g2 = await api.createUserGroup(
        UserGroup.empty(name: n2, description: d2),
      );
      expect(api.groups.length, 2);

      expect(api.groups.keys.contains(g1.id!), true);
      await api.deleteUserGroup(g1.id!);
      expect(api.groups.length, 1);
      expect(api.groups.keys.contains(g1.id!), false);
      expect(api.groups.keys.contains(g2.id!), true);
    });

    tearDown(() async {
      for (String gid in List.from(api.groups.keys)) {
        await api.deleteUserGroup(gid);
      }
    });
  });
}
