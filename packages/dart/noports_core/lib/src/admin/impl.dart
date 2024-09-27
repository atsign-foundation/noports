import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/admin.dart';
import 'package:noports_core/sshnp_foundation.dart';

class PolicyServiceWithAtClient extends PolicyServiceInMem
    with AtClientBindings {
  @override
  final logger = AtSignLogger('PolicyServiceWithAtClient');
  @override
  final AtClient atClient;

  PolicyServiceWithAtClient({
    required super.policyAtSign,
    required this.atClient,
  });

  @override
  Future<void> init() async {
    await super.init();

    logger.shout('Loading groups via AtClient');
    // Fetch all the groups
    List<AtKey> groupKeys = await atClient.getAtKeys(
        regex: '.*.groups.policy.sshnp', sharedBy: policyAtSign);
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
    logger.shout('Completed groups load');

    subscribe(
      regex: r'.*\.groups\.policy\.sshnp',
      shouldDecrypt: true,
    ).listen((AtNotification n) {
      String groupId = n.key.split(':')[1].split('.').first;
      logger.info(
          'Received ${n.operation} notification for group ${n.key} - ID is $groupId');
      if (n.operation == 'delete') {
        groups.remove(groupId);
      } else {
        UserGroup g = UserGroup.fromJson(jsonDecode(n.value!));
        groups[groupId] = g;
      }
    });

    logger.shout('Loading device infos via AtClient');
    // Fetch all the devices
    List<AtKey> diKeys = await atClient.getAtKeys(
        regex: '.*.devices.policy.sshnp', sharedBy: policyAtSign);
    for (final AtKey diKey in diKeys) {
      logger.shout('Loading device from atKey: $diKey');
      final v = await atClient.get(
        diKey,
        getRequestOptions: GetRequestOptions()..useRemoteAtServer = true,
      );
      DeviceInfo di = DeviceInfo.fromJson(jsonDecode(v.value));
      logger.shout('Loaded $diKey - device name is (${di.devicename})');
      deviceInfos[di.devicename] = di;
    }
    logger.shout('Completed device infos load');

    subscribe(
      regex: r'.*\.devices\.policy\.sshnp',
      shouldDecrypt: true,
    ).listen((AtNotification n) {
      logger.shout('Received device heartbeat from ${n.from}');
      final DeviceInfo di = DeviceInfo.fromJson(jsonDecode(n.value!));
      deviceInfos[di.devicename] = di;
      // and store it
      atClient.put(
        AtKey.fromString('${di.devicename}.devices.policy.sshnp$policyAtSign'),
        jsonEncode(di.toJson()),
      );
      onDeviceInfo(di);
    });

    subscribe(
      regex: r'.*\.logs\.policy\.sshnp',
      shouldDecrypt: true,
    ).listen((AtNotification n) {
      logger.shout(
          'Received policy log notification from ${jsonDecode(n.value!)['daemon']}');
      onPolicyLogEvent(PolicyLogEvent.fromJson(jsonDecode(n.value!)));
    });
  }

  String _groupKey(String id) {
    return '$id.groups.policy.sshnp$policyAtSign';
  }

  AtKey _groupAtKey(String id) {
    return AtKey.fromString(_groupKey(id));
  }

  @override
  @mustBeOverridden
  Future<DeviceInfo> createDevice(DeviceInfo di) async {
    await super.createDevice(di);

    // persist in the atServer
    await atClient.put(
      AtKey.fromString('${di.devicename}.devices.policy.sshnp$policyAtSign'),
      jsonEncode(di.toJson()),
      putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
    );

    await onDeviceInfo(di);

    return di;
  }

  @override
  Future<void> deleteDevices() async {
    List<AtKey> diKeys = await atClient.getAtKeys(
        regex: '.*.devices.policy.sshnp', sharedBy: policyAtSign);
    for (final AtKey diKey in diKeys) {
      logger.shout('Deleting $diKey');
      await atClient.delete(
        diKey,
        deleteRequestOptions: DeleteRequestOptions()..useRemoteAtServer = true,
      );
    }
    logger.shout('Completed device infos load');

    await super.deleteDevices();
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
        AtKey.fromString('$policyAtSign:${_groupAtKey(group.id!)}'),
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
        AtKey.fromString('$policyAtSign:${_groupAtKey(group.id!)}'),
        value: jsonEncode(group),
      ),
    );
    groups[group.id!] = group;
  }

  @override
  Future<bool> deleteUserGroup(String id) async {
    await atClient.delete(
      _groupAtKey(id),
      deleteRequestOptions: DeleteRequestOptions()..useRemoteAtServer = true,
    );
    await atClient.notificationService.notify(
      NotificationParams.forDelete(
        AtKey.fromString('$policyAtSign:${_groupAtKey(id)}'),
      ),
    );
    return groups.remove(id) != null;
  }
}

class PolicyServiceInMem implements PolicyService {
  @override
  final String policyAtSign;

  PolicyServiceInMem({required this.policyAtSign});

  @override
  Future<void> init() async {}

  @override
  final Map<String, UserGroup> groups = {};

  @override
  final Map<String, DeviceInfo> deviceInfos = {};

  @override
  final List<PolicyLogEvent> logEvents = [];

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

  Future<void> onDeviceInfo(DeviceInfo di) async {
    final e = {
      'type': 'DeviceInfo',
      'payload': di,
    };
    esc.add(jsonEncode(e));
  }

  Future<void> onPolicyLogEvent(PolicyLogEvent pe) async {
    logEvents.add(pe);
    final e = {
      'type': 'PolicyCheck',
      'payload': pe,
    };
    esc.add(jsonEncode(e));
  }

  StreamController<String> esc = StreamController<String>.broadcast();

  @override
  Stream<String> get eventStream {
    return esc.stream;
  }

  @override
  Future<List<PolicyLogEvent>> getLogEvents(
      {required int from, required int to}) async {
    return List.from(logEvents.where((event) {
      return (event.timestamp >= from && event.timestamp <= to);
    }));
  }

  @override
  Future<UserGroup?> getUserGroup(String id) async {
    return groups[id];
  }

  @override
  Future<List<UserGroup>> getUserGroups() async => List.from(groups.values);

  @override
  @mustBeOverridden
  @mustCallSuper
  Future<DeviceInfo> createDevice(DeviceInfo di) async {
    if (deviceInfos.containsKey(di.devicename)) {
      throw IllegalArgumentException(
          'Device with name ${di.devicename} already exists');
    }
    deviceInfos[di.devicename] = di;

    return di;
  }

  @override
  Future<List<DeviceInfo>> getDevices() async => List.from(deviceInfos.values);

  @override
  Future<void> deleteDevices() async => deviceInfos.clear();

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
