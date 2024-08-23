import 'package:at_client/at_client.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/admin.dart';

class PolicyServiceWithAtClient implements PolicyService {
  final AtClient atClient;

  PolicyServiceWithAtClient({
    required this.atClient,
  });

  @visibleForTesting
  final Map<String, User> users = {};
  @visibleForTesting
  final Map<String, UserGroup> groups = {};

  @override
  Future<UserGroup?> getUserGroup(String id) async {
    return groups[id];
  }

  @override
  Future<List<UserGroup>> getUserGroups() async => List.from(groups.values);

  @override
  Future<void> updateUserGroup(UserGroup group) async {
    final missing = [];
    for (String as in group.userAtSigns) {
      if (!users.containsKey(as)) {
        missing.add(as);
      }
    }
    if (missing.isNotEmpty) {
      throw StateError(
          'Group contains unknown user atSign(s): $missing');
    }
    groups[group.name] = group;
  }

  @override
  Future<bool> deleteUserGroup(String groupId) async {
    return groups.remove(groupId) != null;
  }

  @override
  Future<User?> getUser(String atSign) async {
    return users[atSign];
  }

  @override
  Future<List<User>> getUsers() async => List.from(users.values);

  @override
  Future<List<UserGroup>> getGroupsForUser(String atSign) async {
    List<UserGroup> l = [];

    for (String groupId in groups.keys) {
      UserGroup g = groups[groupId]!;
      if (g.userAtSigns.contains(atSign)) {
        l.add(g);
      }
    }
    return l;
  }

  @override
  Future<void> updateUser(User user) async {
    users[user.atSign] = user;
  }

  @override
  Future<bool> deleteUser(String atSign) async {
    final List<UserGroup> ugs = await getGroupsForUser(atSign);
    if (ugs.isNotEmpty) {
      Set<String> groupNames = {};
      for (final ug in ugs) {
        groupNames.add(ug.name);
      }
      print ('$groupNames');
      throw StateError('May not delete a user'
          ' who is still a member of any group.'
          ' Currently member of $groupNames');
    }
    return users.remove(atSign) != null;
  }
}
