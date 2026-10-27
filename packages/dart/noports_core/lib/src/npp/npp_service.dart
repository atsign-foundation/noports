import 'package:at_cli_commons/at_cli_commons.dart';
import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/npp.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/src/events/noports_event_types.dart';

class NppRequestHandler implements NPARequestHandler {
  final NppCache nppCache;

  NppRequestHandler({
    required this.nppCache
  });

  @override
  bool hasRulesFor(Atsign daemonAtsign) =>
      nppCache.hasServiceACLsForDaemon(daemonAtsign);

  @override
  Future<NPAAuthCheckResponse> doAuthCheck(NPAAuthCheckRequest authCheckRequest) async {
    final String clientAtSign = authCheckRequest.clientAtsign;
    final String daemonAtSign = authCheckRequest.daemonAtsign;
    final String deviceName = authCheckRequest.daemonDeviceName;
    final String deviceGroupName = authCheckRequest.daemonDeviceGroupName;

    final Set<ServiceACL> matchedServiceACLs =
      nppCache.findMatchedServiceACLs(
        clientAtSign: clientAtSign,
        daemonAtSign: daemonAtSign,
        deviceName: deviceName,
        deviceGroupName: deviceGroupName);

    final List<String> permitOpens = [];
    for(final ServiceACL sacl in matchedServiceACLs) {
      permitOpens.add(sacl.permitOpen);
    }

    // authorized bool doesn't actually make sense
    // sshnpd's should be checking the permitOpens for when doing a true
    // policy check
    final bool authorized = permitOpens.isNotEmpty;

    NPAAuthCheckResponse response;
    if(authorized) {
      response = NPAAuthCheckResponse(
        authorized: true,
        message: '${authCheckRequest.clientAtsign} has permission'
            ' for device ${authCheckRequest.daemonDeviceName}'
            ' and/or device group ${authCheckRequest.daemonDeviceGroupName}'
            ' at daemon ${authCheckRequest.daemonAtsign}',
        permitOpen: permitOpens);
    } else {
      response = NPAAuthCheckResponse(
        authorized: false,
        message: 'No permissions for ${authCheckRequest.clientAtsign}'
            ' at ${authCheckRequest.daemonAtsign}'
            ' for either the device ${authCheckRequest.daemonDeviceName}'
            ' or the deviceGroup ${authCheckRequest.daemonDeviceGroupName}',
        permitOpen: permitOpens);
    }
    return response;

  }
}

class NppServiceDefaults {
  static const String baseNamespace = 'sshnp';
  static const String domainNamespace = 'npp';
  static const Duration heartbeatInterval = Duration(seconds: 60);

  /// The shortest heartbeat interval [NppService] accepts, so no policy
  /// service writes to its event logging Atsign more often than this.
  static const Duration minHeartbeatInterval = Duration(seconds: 30);
}

class NppService {
  // mandatory
  final AtClient atClient;
  final NppCache nppCache;
  final Set<String> managerAllowList; // set of atSigns who can talk to policy manager api rpc (put/get policy rules)
  final String binariesVersion;

  // optional
  final String? eventLoggingAtSign;
  final String baseNamespace;
  final String domainNamespace;
  final String? homeDirectory;
  final NppOperationHooks? nppOperationHooks;
  final String? persistenceMethod; // where the rules were loaded from: 'atserver', 'file' or 'none'
  final Duration heartbeatInterval; // how often start() sends a heartbeat; at least NppServiceDefaults.minHeartbeatInterval

  // instantiated from init()
  late NPA npa; // responds to policy requests
  late AtRpc managerRpcListener; // policy api (put/get/delete/ping)
  Timer? _heartbeat;
  DateTime? _startedAt;
  bool _stopped = false;

  NppService({
    required this.atClient,
    required this.nppCache,
    required this.managerAllowList,
    required this.binariesVersion,
    this.eventLoggingAtSign,
    this.baseNamespace = NppServiceDefaults.baseNamespace,
    this.domainNamespace = NppServiceDefaults.domainNamespace,
    this.homeDirectory,
    this.nppOperationHooks,
    this.persistenceMethod,
    this.heartbeatInterval = NppServiceDefaults.heartbeatInterval,
  });

  void init() {
    if (heartbeatInterval < NppServiceDefaults.minHeartbeatInterval) {
      throw ArgumentError.value(heartbeatInterval, 'heartbeatInterval',
          'must be at least ${NppServiceDefaults.minHeartbeatInterval}');
    }
    String? homeDir = homeDirectory;
    if(homeDir == null) {
      homeDir = getHomeDirectory();
      if(homeDir == null) {
        throw Exception('Home directory could not be resolved.');
      }
    }
    final handler = NppRequestHandler(nppCache: nppCache);
    npa = NPAImpl(
      handler: handler,
      atClient: atClient,
      homeDirectory: homeDir,
      eventLoggingAtsign: eventLoggingAtSign?.toAtsign());

    managerRpcListener = AtRpc(
      atClient: atClient,
      callbacks: ManagerRpcCallbacks(
        atClient: atClient,
        nppCache: nppCache,
        nppOperationHooks: nppOperationHooks,
        binariesVersion: binariesVersion,
        handler: handler,
      ),
      isClient: false,
      isServer: true,
      allowAll: false, // people not on the managerAllowList should not be allowed to change policy rules
      allowList: managerAllowList,
      baseNameSpace: baseNamespace,
      domainNameSpace: domainNamespace);
  }

  /// Starts answering policy checks, tells the event logging Atsign which
  /// rules were loaded, then starts the manager RPC. The event is sent first
  /// so that no manager RPC can change the rules before they are counted.
  /// With an event logging Atsign, it then sends a heartbeat every
  /// [heartbeatInterval] until [stop].
  Future<void> start() async {
    _startedAt = DateTime.now();
    await npa.run();
    await npa.sendEvent(PolicyEvent.rulesLoaded(
      policyAtsign: npa.policyAtsign,
      persistenceMethod: persistenceMethod,
      binariesVersion: binariesVersion,
      rules: _ruleCounts(),
    ));
    managerRpcListener.start();
    if (npa.eventLoggingAtsign != null) {
      _heartbeat = Timer.periodic(
          heartbeatInterval, (_) => unawaited(sendHeartbeat()));
    }
  }

  /// Sends a heartbeat with the current rule counts, as [start]'s timer does.
  @visibleForTesting
  Future<void> sendHeartbeat() => npa.sendEvent(PolicyEvent.heartbeat(
    policyAtsign: npa.policyAtsign,
    interval: heartbeatInterval,
    rules: _ruleCounts(),
  ));

  /// Whether [start]'s heartbeat timer is running.
  @visibleForTesting
  bool get heartbeatRunning => _heartbeat?.isActive ?? false;

  /// Stops the heartbeat, tells the event logging Atsign the service is
  /// stopping and why, then waits (at most 5 s) for every event already sent
  /// to reach our atServer. Only the first call does anything. Checks are
  /// still answered until the process exits, since an AtRpc can't be stopped.
  Future<void> stop({required String reason}) async {
    if (_stopped) return;
    _stopped = true;
    _heartbeat?.cancel();
    await npa.sendEvent(PolicyEvent.stopped(
      policyAtsign: npa.policyAtsign,
      reason: reason,
      uptime: DateTime.now().difference(_startedAt ?? DateTime.now()),
    ));
    await npa.flushEvents();
  }

  /// How many of each kind of rule the cache holds now.
  Map<String, int> _ruleCounts() => {
    'clients': nppCache.clients.length,
    'clientGroups': nppCache.clientGroups.length,
    'clientGroupMembers': nppCache.clientGroupMembers.length,
    'daemons': nppCache.daemons.length,
    'services': nppCache.services.length,
    'serviceACLs': nppCache.serviceACLs.length,
  };
}
