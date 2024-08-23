import 'package:noports_core/admin.dart';
import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAtClient extends Mock implements AtClient {}

void main() {
  MockAtClient atClient = MockAtClient();

  group('core create retrieve update delete', () {
    PolicyServiceWithAtClient api =
        PolicyService.withAtClient(atClient: atClient)
            as PolicyServiceWithAtClient;

    setUp(() async {
      expect(api.users, isEmpty);
      expect(api.groups, isEmpty);
    });

    test('add user', () async {
      String as = '@alice';
      expect((await api.getUser(as)), isNull);

      await api.updateUser(User(atSign: as, name: 'Alice'));
      expect(api.users.containsKey(as), true);
      expect(api.users[as]!.atSign, '@alice');
      expect(api.users[as]!.name, 'Alice');

      User? u = await api.getUser(as);
      expect(u, isNotNull);
      expect(u!.atSign, as);
      expect(u.name, 'Alice');
    });

    test('update user', () async {
      String as = '@alice';
      expect((await api.getUser(as)), isNull);

      await api.updateUser(User(atSign: as, name: 'Alice'));
      await api.updateUser(User(atSign: '@bob', name: 'Bob'));

      User u = (await api.getUser(as))!;
      expect(u.atSign, as);
      expect(u.name, 'Alice');

      await api.updateUser(User(atSign: as, name: 'Still Alice'));
      u = (await api.getUser(as))!;
      expect(u.atSign, as);
      expect(u.name, 'Still Alice');

      expect(api.users.length, 2);
    });

    test('delete user', () async {
      String as = '@alice';
      expect((await api.getUser(as)), isNull);

      await api.updateUser(User(atSign: as, name: 'Alice'));
      await api.updateUser(User(atSign: '@bob', name: 'Bob'));
      expect(api.users.length, 2);

      await api.deleteUser(as);
      expect(api.users.length, 1);
      expect(api.users.keys, contains('@bob'));
    });

    test('add group', () async {
      String gid = 'sysadmins';
      String d = 'Description';
      expect((await api.getUserGroup(gid)), isNull);

      await api.updateUserGroup(
        UserGroup.empty(
          name: gid,
          description: d,
        ),
      );

      expect(api.groups.containsKey(gid), true);
      expect(api.groups[gid]!.name, gid);
      expect(api.groups[gid]!.description, d);

      UserGroup? ug = await api.getUserGroup(gid);
      expect(ug, isNotNull);
      expect(ug!.name, gid);
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
      expect((await api.getUserGroup(n1)), isNull);

      await api.updateUserGroup(
        UserGroup.empty(name: n1, description: d1),
      );
      expect(api.groups.length, 1);

      await api.updateUserGroup(
        UserGroup.empty(name: n2, description: d2),
      );
      expect(api.groups.length, 2);

      UserGroup g1 = (await api.getUserGroup(n1))!;
      expect(g1.name, n1);
      expect(g1.description, d1);

      UserGroup g2 = (await api.getUserGroup(n2))!;
      expect(g2.name, n2);
      expect(g2.description, d2);

      await api.updateUserGroup(
        UserGroup.empty(
          name: n1,
          description: 'Updated description',
        ),
      );
      expect(api.groups.length, 2);

      g1 = (await api.getUserGroup(n1))!;
      expect(g1.name, n1);
      expect(g1.description, 'Updated description');

      g2 = (await api.getUserGroup(n2))!;
      expect(g2.name, n2);
      expect(g2.description, d2);
    });

    test('delete group', () async {
      String n1 = 'sysadmins';
      String d1 = 'Description';
      String n2 = 'some other group';
      String d2 = 'some other group description';
      expect((await api.getUserGroup(n1)), isNull);

      await api.updateUserGroup(
        UserGroup.empty(name: n1, description: d1),
      );
      expect(api.groups.length, 1);

      await api.updateUserGroup(
        UserGroup.empty(name: n2, description: d2),
      );
      expect(api.groups.length, 2);

      expect(api.groups.keys.contains(n1), true);
      await api.deleteUserGroup(n1);
      expect(api.groups.length, 1);
      expect(api.groups.keys.contains(n1), false);
      expect(api.groups.keys.contains(n2), true);
    });

    tearDown(() async {
      for (String gid in List.from(api.groups.keys)) {
        await api.deleteUserGroup(gid);
      }
      for (String uas in List.from(api.users.keys)) {
        await api.deleteUser(uas);
      }
    });
  });

  group('group memberships', () {
    PolicyServiceWithAtClient api =
        PolicyService.withAtClient(atClient: atClient)
            as PolicyServiceWithAtClient;

    late UserGroup sa;
    late UserGroup ug2;
    setUp(() async {
      expect(api.users, isEmpty);
      expect(api.groups, isEmpty);

      sa = UserGroup.empty(
        name: 'sysadmins',
        description: 'Description',
      );
      ug2 = UserGroup.empty(
        name: 'other_user_group',
        description: 'Some other user group',
      );

      await api.updateUserGroup(sa);
      await api.updateUserGroup(ug2);
    });

    test('cannot add an unknown user to a group', () async {
      sa.userAtSigns.add('@unknown');
      await expectLater(api.updateUserGroup(sa), throwsStateError);
    });

    test('delete user when member of one group', () async {
      var atSign = '@alice';
      await api.updateUser(User(atSign: atSign, name: 'Alice'));
      sa.userAtSigns.add(atSign);
      await api.updateUserGroup(sa);
      await expectLater(
          api.deleteUser(atSign),
          throwsA(predicate(
            (e) =>
                e is StateError &&
                e.message ==
                    'May not delete a user'
                        ' who is still a member of any group.'
                        ' Currently member of {sysadmins}',
          )));
    });

    test('delete user when member of two groups', () async {
      var atSign = '@alice';
      await api.updateUser(User(atSign: atSign, name: 'Alice'));
      sa.userAtSigns.add(atSign);
      await api.updateUserGroup(sa);
      ug2.userAtSigns.add(atSign);
      await api.updateUserGroup(ug2);
      await expectLater(
          api.deleteUser(atSign),
          throwsA(predicate((e) =>
              e is StateError &&
              e.message.contains('{sysadmins, other_user_group}'))));
    });

    test('test get users groups', () async {
      var atSign = '@alice';
      await api.updateUser(User(atSign: atSign, name: 'Alice'));

      sa.userAtSigns.add(atSign);
      await api.updateUserGroup(sa);
      List groups = await api.getGroupsForUser(atSign);
      Map<String, UserGroup> groupsMap = Map.fromIterable(groups,
          key: (group) => group.name, value: (group) => group);
      expect(groupsMap.containsKey(sa.name), true);
      expect(groups.length, 1);

      ug2.userAtSigns.add(atSign);
      await api.updateUserGroup(ug2);
      groups = await api.getGroupsForUser(atSign);
      groupsMap = Map.fromIterable(groups,
          key: (group) => group.name, value: (group) => group);
      expect(groupsMap.containsKey(sa.name), true);
      expect(groupsMap.containsKey(ug2.name), true);
      expect(groups.length, 2);
    });

    tearDown(() async {
      for (String gid in List.from(api.groups.keys)) {
        await api.deleteUserGroup(gid);
      }
      for (String uas in List.from(api.users.keys)) {
        await api.deleteUser(uas);
      }
    });
  });
}
