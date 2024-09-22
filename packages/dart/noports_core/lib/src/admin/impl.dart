import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/admin.dart';
import 'package:noports_core/sshnp_foundation.dart';

class PolicyServiceWithAtClient extends PolicyServiceInMem
    with AtClientBindings {
  @override
  final logger = AtSignLogger('PolicyServiceWithAtClient');
  @override
  final AtClient atClient;

  PolicyServiceWithAtClient({
    required this.atClient,
  });

  @override
  Future<void> init() async {
    await super.init();

    atClient.notificationService
        .subscribe(
      regex: r'.*\.groups\.policy\.sshnp',
      shouldDecrypt: true,
    )
        .listen((AtNotification n) {
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

    subscribe(
      regex: r'.*\.logs\.policy\.sshnp',
      shouldDecrypt: true,
    ).listen((AtNotification n) {
      logger.shout(
          'Received policy log notification from ${jsonDecode(n.value!)['daemon']}');
      // TODO Make a PolicyLogEvent and use PolicyLogEvent.fromJson()
      onPolicyLogEvent(n.value!);
    });

    subscribe(
      regex: r'.*\.devices\.policy\.sshnp',
      shouldDecrypt: true,
    ).listen((AtNotification n) {
      logger.shout('Received device heartbeat from ${n.from}');
      // TODO Make a PolicyLogEvent and use PolicyLogEvent.fromJson()
      final v = jsonDecode(n.value!);
      final e = {};
      e['timestamp'] = n.epochMillis;
      e['daemon'] = n.from;
      e['payload'] = v;
      onDaemonEvent(jsonEncode(e));
    });

    logger.shout('Loading groups via AtClient');
    // Fetch all the groups
    List<AtKey> groupKeys = await atClient.getAtKeys(
        regex: '.*.groups.policy.sshnp', sharedBy: atClient.getCurrentAtSign());
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
        AtKey.fromString(
            '${atClient.getCurrentAtSign()}:${_groupAtKey(group.id!)}'),
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
        AtKey.fromString(
            '${atClient.getCurrentAtSign()}:${_groupAtKey(group.id!)}'),
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
        AtKey.fromString('${atClient.getCurrentAtSign()}:${_groupAtKey(id)}'),
      ),
    );
    return groups.remove(id) != null;
  }
}

class PolicyServiceInMem implements PolicyService {
  @override
  Future<void> init() async {}

  @override
  final Map<String, UserGroup> groups = {};

  @override
  final List<dynamic> logEvents = [];

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

  Future<void> onDaemonEvent(json) async {
    final de = jsonDecode(json);
    final e = {
      'timestamp': de['timestamp'],
      'type': 'DaemonHeartbeat',
      'daemon': de['daemon'],
      'deviceName': de['payload']['devicename'],
      'deviceGroupName': de['payload']['deviceGroupName'],
    };
    esc.add(jsonEncode(e));
  }

  Future<void> onPolicyLogEvent(json) async {
    final pe = jsonDecode(json);
    logEvents.add(pe);
    final e = {
      'timestamp': pe['timestamp'],
      'type': 'PolicyCheck',
      'daemon': pe['daemon'],
      'deviceName': pe['payload']['request']['payload']['daemonDeviceName'],
      'deviceGroupName': pe['payload']['request']['payload']
          ['daemonDeviceGroupName'],
      'user': pe['payload']['request']['payload']['clientAtsign'],
      'authorized': pe['payload']['response']['payload']['authorized'],
      'message': pe['payload']['response']['payload']['message'],
      'permitOpen': pe['payload']['response']['payload']['permitOpen'],
    };
    esc.add(jsonEncode(e));
  }

  StreamController<String> esc = StreamController<String>.broadcast();

  @override
  Stream<String> get eventStream {
    return esc.stream;
  }

  @override
  Future<List<dynamic>> getLogEvents(
      {required int from, required int to}) async {
    return List.from(logEvents.where((event) {
      int ts = event['timestamp'];
      return (ts >= from && ts <= to);
    }));
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
