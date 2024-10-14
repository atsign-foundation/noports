import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_policy/at_policy.dart';
import 'package:at_policy/src/mixins/at_client_bindings.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

class PolicyServiceImpl with AtClientBindings implements PolicyService {
  @override
  final AtSignLogger logger = AtSignLogger(' PolicyServiceImpl ');

  @override
  late AtClient atClient;

  @override
  final String homeDirectory;

  @override
  final String baseNamespace;

  @override
  String get authorizerAtsign => atClient.getCurrentAtSign()!;

  @override
  String get loggingAtsign => atClient.getCurrentAtSign()!;

  @override
  final Set<String> deviceAtsigns;

  @override
  final PolicyRequestHandler handler;

  static const JsonEncoder jsonPrettyPrinter = JsonEncoder.withIndent('    ');

  PolicyServiceImpl({
    // final fields
    required this.baseNamespace,
    required this.atClient,
    required this.homeDirectory,
    required this.deviceAtsigns,
    required this.handler,
  }) {
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;
  }

  static Future<PolicyService> fromCommandLineArgs(
    List<String> args, {
    required PolicyRequestHandler handler,
    AtClient? atClient,
    FutureOr<AtClient> Function(PolicyServiceParams)? atClientGenerator,
    void Function(Object, StackTrace)? usageCallback,
    Set<String>? daemonAtsigns,
  }) async {
    try {
      var p = await PolicyServiceParams.fromArgs(args);

      // Check atKeyFile selected exists
      if (!await File(p.atKeysFilePath).exists()) {
        throw ('\n Unable to find .atKeys file : ${p.atKeysFilePath}');
      }

      AtSignLogger.root_level = 'SHOUT';
      if (p.verbose) {
        AtSignLogger.root_level = 'INFO';
      }

      if (atClient == null && atClientGenerator == null) {
        throw StateError('atClient and atClientGenerator are both null');
      }

      atClient ??= await atClientGenerator!(p);

      var sshnpa = PolicyServiceImpl(
        baseNamespace: p.baseNamespace,
        atClient: atClient,
        homeDirectory: p.homeDirectory,
        deviceAtsigns: daemonAtsigns ?? p.daemonAtsigns,
        handler: handler,
      );

      if (p.verbose) {
        sshnpa.logger.logger.level = Level.INFO;
      }

      return sshnpa;
    } catch (e, s) {
      usageCallback?.call(e, s);
      rethrow;
    }
  }

  @override
  Future<void> run() async {
    AtRpc rpc = AtRpc(
      atClient: atClient,
      baseNameSpace: baseNamespace,
      domainNameSpace: 'requests.policy',
      callbacks: this,
      allowList: deviceAtsigns,
      allowAll: true,
    );

    rpc.start();

    logger.info('Listening for requests at '
        '${rpc.domainNameSpace}.${rpc.rpcsNameSpace}.${rpc.baseNameSpace}');
  }

  @override
  Future<AtRpcResp> handleRequest(AtRpcReq rpcRequest, String fromAtSign) async {
    logger.info('Received request from $fromAtSign: '
        '${jsonPrettyPrinter.convert(rpcRequest.toJson())}');

    PolicyRequest policyRequest = PolicyRequest.fromJson(rpcRequest.payload);

    // We will send a 'log' notification to the loggingAtsign
    var logKey = AtKey()
      ..key = '${DateTime.now().millisecondsSinceEpoch}.logs.policy'
      ..sharedBy = authorizerAtsign
      ..sharedWith = loggingAtsign
      ..namespace = baseNamespace
      ..metadata = (Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true);

    final event = PolicyLogEvent(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      deviceAtsign: fromAtSign,
      policyAtsign: atClient.getCurrentAtSign(),
      devicename: policyRequest.daemonDeviceName,
      deviceGroupName: policyRequest.daemonDeviceGroupName,
      clientAtsign: policyRequest.clientAtsign,
      eventType: PolicyLogEventType.requestFromDevice,
      eventDetails: {'intents': policyRequest.intents},
      message: '',
    );
    await notify(
      logKey,
      jsonEncode(event),
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
      ttln: Duration(hours: 1),
    );

    PolicyResponse authCheckResponse;
    AtRpcResp rpcResponse;
    try {
      authCheckResponse = await handler.doAuthCheck(policyRequest);
      rpcResponse = AtRpcResp(
          reqId: rpcRequest.reqId,
          respType: AtRpcRespType.success,
          payload: authCheckResponse.toJson());
    } catch (e, st) {
      logger.shout('Exception: $e : StackTrace : \n$st');
      authCheckResponse = PolicyResponse(
        message: 'Exception: $e',
        policyInfos: [],
      );
      rpcResponse = AtRpcResp(
          reqId: rpcRequest.reqId,
          respType: AtRpcRespType.success,
          payload: authCheckResponse.toJson());
    }

    return rpcResponse;
  }

  /// We're not sending any RPCs so we don't implement `handleResponse`
  @override
  Future<void> handleResponse(AtRpcResp response) {
    throw UnimplementedError();
  }
}

class PolicyApiWithAtClient extends PolicyApiInMemory with AtClientBindings {
  @override
  final logger = AtSignLogger('PolicyServiceWithAtClient');
  @override
  final AtClient atClient;

  PolicyApiWithAtClient({
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

class PolicyApiInMemory implements PolicyAPI {
  @override
  final String policyAtSign;

  PolicyApiInMemory({required this.policyAtSign});

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
