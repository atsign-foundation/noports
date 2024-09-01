import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/admin.dart';

class PolicyServiceWithAtClient extends PolicyServiceInMem {
  final logger = AtSignLogger('PolicyServiceWithAtClient');
  final AtClient atClient;

  PolicyServiceWithAtClient({
    required this.atClient,
  });

  @override
  Future<void> init() async {
    await super.init();

    atClient.notificationService.subscribe(
      regex: r'.*\.groups\.policy\.sshnp',
      shouldDecrypt: true,
    ).listen((AtNotification n) {
      String groupId = n.key.split(':')[1].split('.').first;
      logger.info('Received ${n.operation} notification for group ${n.key} - ID is $groupId');
      if (n.operation == 'delete') {
        groups.remove(groupId);
      } else {
        UserGroup g = UserGroup.fromJson(jsonDecode(n.value!));
        groups[groupId] = g;
      }
    });

    logger.shout('Loading groups via AtClient');
    // Fetch all the groups
    List<AtKey> groupKeys = await atClient.getAtKeys(
        regex: '.*.groups.policy.sshnp',
        sharedBy: atClient.getCurrentAtSign());
    for (final AtKey groupKey in groupKeys) {
      logger.shout('Loading group from atKey: $groupKey');
      final v = await atClient.get(
        groupKey,
        getRequestOptions: GetRequestOptions()..useRemoteAtServer = true,
      );
      UserGroup g = UserGroup.fromJson(jsonDecode(v.value));
      logger.shout('Loaded $groupKey - group name is (${g.name})');
      groups[g.id!] = g;
    }
    logger.shout('Load complete');
  }

  String _groupKey(String id) {
    return '$id.groups.policy.sshnp${atClient.getCurrentAtSign()!}';
  }

  AtKey _groupAtKey(String id) {
    return AtKey.fromString(_groupKey(id));
  }
  @override
  Future<UserGroup> createUserGroup(UserGroup group) async {
    if (group.id != null) {
      throw StateError('New groups must not already have an ID');
    }
    group.id = '${_maxGroupId() + 1}';

    await atClient.put(
      _groupAtKey(group.id!),
      jsonEncode(group),
      putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
    );
    await atClient.notificationService.notify(
      NotificationParams.forUpdate(
        AtKey.fromString('${atClient.getCurrentAtSign()}:${_groupAtKey(group.id!)}'),
        value: jsonEncode(group),
      ),
    );
    groups[group.id!] = group;
    return group;
  }

  @override
  Future<void> updateUserGroup(UserGroup group) async {
    if (group.id == null) {
      throw StateError('Existing groups must already have an ID');
    }
    await atClient.put(
      _groupAtKey(group.id!),
      jsonEncode(group),
      putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
    );
    await atClient.notificationService.notify(
      NotificationParams.forUpdate(
        AtKey.fromString('${atClient.getCurrentAtSign()}:${_groupAtKey(group.id!)}'),
        value: jsonEncode(group),
      ),
    );
    groups[group.id!] = group;
  }

  @override
  Future<bool> deleteUserGroup(String id) async {
    await atClient.delete(_groupAtKey(id),
      deleteRequestOptions: DeleteRequestOptions()..useRemoteAtServer = true,
    );
    await atClient.notificationService.notify(
      NotificationParams.forDelete(
        AtKey.fromString('${atClient.getCurrentAtSign()}:${_groupAtKey(id)}'),
      ),
    );
    return groups.remove(id) != null;
  }
}

class PolicyServiceInMem implements PolicyService {
  @override
  Future<void> init() async {

  }

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
  Set<String> get daemonAtSigns {
    final Set<String> s = {};
    for (final g in groups.values) {
      s.addAll(g.daemonAtSigns);
    }
    return s;
  }
}
