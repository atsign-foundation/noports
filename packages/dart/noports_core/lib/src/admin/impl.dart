import 'package:at_client/at_client.dart';
import 'package:noports_core/admin.dart';

class PolicyServiceWithAtClient implements PolicyService {
  final AtClient atClient;

  PolicyServiceWithAtClient({
    required this.atClient,
  });

  final Map<String, UserGroup> groups = {};

  int _maxGroupId() {
    int i = 0;
    for (final g in groups.values) {
      int gid = int.parse(g.id!);
      if (gid > i) {
        i = gid;
      }
    }
    return i;
  }
  @override
  Future<UserGroup?> getUserGroup(String id) async {
    return groups[id];
  }

  @override
  Future<List<UserGroup>> getUserGroups() async => List.from(groups.values);

  @override
  Future<UserGroup> createUserGroup(UserGroup group) async {
    if (group.id != null) {
      throw StateError('New groups must not already have an ID');
    }
    group.id = '${_maxGroupId() + 1}';
    groups[group.id!] = group;
    return group;
  }

  @override
  Future<void> updateUserGroup(UserGroup group) async {
    if (group.id == null) {
      throw StateError('Existing groups must already have an ID');
    }
    groups[group.id!] = group;
  }

  @override
  Future<bool> deleteUserGroup(String id) async {
    return groups.remove(id) != null;
  }
}
