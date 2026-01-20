import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:at_client/at_client.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/admin.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:sshnoports/src/create_at_client_cli.dart';
import 'package:noports_core/admin_v2.dart' as admin_v2;

late AtSignLogger logger;

void main(List<String> args) async {
  try {
    if (NPAParams.parser.parse(args)['help'] == true) {
      print(NPAParams.parser.usage);
      exit(0);
    }
  } on ArgumentError catch (e) {
    stderr.writeln('Usage: \n${NPAParams.parser.usage}\n');
    stderr.writeln(e.message);
    exit(1);
  } on FormatException catch (e) {
    stderr.writeln('Usage: \n${NPAParams.parser.usage}\n');
    stderr.writeln(e.message);
    exit(1);
  } catch (err) {
    stderr.writeln('Usage: \n${NPAParams.parser.usage}\n');
    stderr.writeln(err);
    exit(1);
  }

  final NPAParams p;
  try {
    p = await NPAParams.fromArgs(args);
  } catch (err) {
    stderr.writeln('Usage: \n${NPAParams.parser.usage}\n');
    stderr.writeln(err);
    exit(1);
  }

  // Check atKeyFile selected exists
  if (!await File(p.atKeysFilePath).exists()) {
    stderr.writeln('\n Unable to find .atKeys file : ${p.atKeysFilePath}');
    exit(2);
  }

  AtSignLogger.root_level = 'SHOUT';
  if (p.verbose) {
    AtSignLogger.root_level = 'INFO';
  }
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;

  logger = AtSignLogger(' npp ');
  final AtClient atClient;
  try {
    atClient = await createAtClientCli(
      atsign: p.policyAtsign,
      atKeysFilePath: p.atKeysFilePath,
      rootDomain: p.rootDomain,
      atServiceFactory: ServiceFactoryWithNoOpSyncService(),
      namespace: DefaultArgs.namespace,
      storagePath: p.storagePath ??
          standardAtClientStoragePath(
              baseDir: p.homeDirectory,
              atSign: p.policyAtsign,
              progName: '.${DefaultArgs.namespace}',
              uniqueID: 'single'),
    );
  } catch (err) {
    stderr.writeln(err);
    exit(3);
  }

  logger.info('Detected policy version: ${p.policyVersion}');

  if(p.policyVersion == 'v1') {
    Handler handler = Handler(atClient);
    try {
      await handler.init();
    } catch (err) {
      stderr.writeln(err);
      exit(4);
    }

    var sshnpa = NPAImpl(
      atClient: atClient,
      homeDirectory: p.homeDirectory,
      handler: handler,
      eventLoggingAtsign: p.eventLoggingAtsign,
    );

    if (p.verbose) {
      sshnpa.logger.logger.level = Level.INFO;
    }

    // start updating the heartbeat atkey periodically
    Timer.periodic(const Duration(seconds: 60), (_) async {
      // key format: `heartbeat.noports@<atsign>`: {'timestamp': '...'}
      await _updateHeartbeatKey(atClient);
    });

    // start listening for force heartbeats from the same atSign
    logger.shout('Starting AtRpc Server to listen for forced heartbeats...');
    AtRpc(
      atClient: atClient,
      baseNameSpace: 'sshnp',
      domainNameSpace: 'npp_atserver_heartbeat',
      callbacks: _HeartbeatHelper(atClient: atClient),
      allowList: {atClient.getCurrentAtSign()!}.toSet(),
      isServer: true,
      isClient: false,
    ).start();

    await sshnpa.run();
  } else if(p.policyVersion == 'v2') {

    final admin_v2.PolicyCache policyCache = admin_v2.PolicyCache();

    // 1. Import default policyCache data
    await _populatePolicyCacheFromAtServer(
      policyCache: policyCache,
      atClient: atClient,
      domainNamespace: 'policy_v2', // TODO: make this a const somewhere
      baseNamespace: DefaultArgs.namespace,
      );

    
    final admin_v2.PolicyService policyService = admin_v2.PolicyService(
      policyOperationHooks: generatePolicyOperationHooks(
        atClient: atClient,
        domainNamespace: 'policy_v2', // TODO: make this a const somewhere
        baseNamespace: DefaultArgs.namespace,
        ),
      atClient: atClient,
      allowList: p.allowList.split(',').toSet(),
      policyCache: policyCache,
      );

    await policyService.start();
  } else {
    stderr.writeln('Unknown policy version: ${p.policyVersion}');
    exit(4);
  }
}

class Handler implements NPARequestHandler {
  final AtClient atClient;
  late final PolicyServiceWithAtClient api;

  Handler(this.atClient) {
    api = PolicyServiceWithAtClient(atClient: atClient);
  }

  Future<void> init() async {
    await api.init();
  }

  @override
  Future<NPAAuthCheckResponse> doAuthCheck(
      NPAAuthCheckRequest authCheckRequest) async {
    logger.info('Checking policy for request: $authCheckRequest');
    // member of any groups?
    final groups = await api.getGroupsForUser(authCheckRequest.clientAtsign);
    if (groups.isEmpty) {
      return NPAAuthCheckResponse(
        authorized: false,
        message: 'No permissions for ${authCheckRequest.clientAtsign}',
        permitOpen: [],
      );
    }

    // OK - user is in some groups. What's it permitted to talk to?
    Set<String> permitOpens = {};

    // for each group
    // does it contain the authCheckRequest.daemonAtsign?
    for (final group in groups) {
      if (group.daemonAtSigns.contains(authCheckRequest.daemonAtsign)) {
        // does it contain a matching deviceName? if so, add the permitOpens
        for (final d in group.devices) {
          if (d.name == authCheckRequest.daemonDeviceName) {
            permitOpens.addAll(d.permitOpens);
          }
        }
        // or a matching deviceGroupName? if so, add the permitOpens
        for (final dg in group.deviceGroups) {
          if (dg.name == authCheckRequest.daemonDeviceGroupName) {
            permitOpens.addAll(dg.permitOpens);
          }
        }
      }
    }

    if (permitOpens.isNotEmpty) {
      return NPAAuthCheckResponse(
        authorized: true,
        message: '${authCheckRequest.clientAtsign} has permission'
            ' for device ${authCheckRequest.daemonDeviceName}'
            ' and/or device group ${authCheckRequest.daemonDeviceGroupName}'
            ' at daemon ${authCheckRequest.daemonAtsign}',
        permitOpen: List<String>.from(permitOpens),
      );
    } else {
      return NPAAuthCheckResponse(
        authorized: false,
        message: 'No permissions for ${authCheckRequest.clientAtsign}'
            ' at ${authCheckRequest.daemonAtsign}'
            ' for either the device ${authCheckRequest.daemonDeviceName}'
            ' or the deviceGroup ${authCheckRequest.daemonDeviceGroupName}',
        permitOpen: [],
      );
    }
  }
}

Future<bool> _updateHeartbeatKey(final AtClient atClient) async {
  final timestamp = DateTime.timestamp().toUtc();
  final atKey = AtKey()
        ..key = 'heartbeat'
        ..sharedBy = atClient.getCurrentAtSign()
        ..namespace = DefaultArgs.namespace // sshnp
      ;

  final objData = {
    'timestamp': timestamp.toIso8601String(),
    'interval': 60, // seconds
  };

  try {
    final bool success = await atClient.put(atKey, jsonEncode(objData),
        putRequestOptions: PutRequestOptions()
          ..shouldEncrypt = true
          ..useRemoteAtServer = true);

    logger.info(
        'Put timestamp key `${atKey.toString()}`: $timestamp, success: $success');
    return success;
  } catch (e) {
    logger.severe('Failed to write heartbeat timestamp: $e');
    return false;
  }
}

class _HeartbeatHelper implements AtRpcCallbacks {
  late AtClient atClient;

  _HeartbeatHelper({required this.atClient});

  @override
  Future<AtRpcResp> handleRequest(AtRpcReq request, String fromAtSign) async {
    logger.shout('Received heartbeat. Updating heartbeat key...');
    // someone is trying to force a heartbeat on us
    if (fromAtSign != atClient.getCurrentAtSign()) {
      return AtRpcResp(
          reqId: request.reqId,
          respType: AtRpcRespType.error,
          payload: {
            'success': false,
            'message':
                'You currently cannot force heartbeat as another atSign other than the policy atSign itself.'
          },
          message:
              'You currently cannot force heartbeat as another atSign other than the policy atSign itself.');
    }

    // great, now we're the current atSign
    final bool success = await _updateHeartbeatKey(atClient);
    logger.shout('Sending AtRpcResp...');
    return AtRpcResp(
        reqId: request.reqId,
        respType: AtRpcRespType.success,
        payload: {'success': success},
        message: 'Successfully forced heartbeat.');
  }

  @override
  Future<void> handleResponse(AtRpcResp response) async {
    throw UnimplementedError(
        ':('); // we are only receiving messages, not sending messages.
  }
}

/// Populate the policy cache by fetching AtKeys from the atServer.
/// 1) *.client.policy.sshnp --> a client (e.g. "@alice", "Alice")
/// 2) *.client_group.policy.sshnp --> a client group (e.g. client.id, "Atsign Engineers")
/// 3) *.client_group_member.policy.sshnp --> maps client to a client group (e.g. client.id, client_group.id)
/// 4) *.daemon.policy.sshnp --> a daemon (e.g. "@device")
/// 5) *.service.policy.sshnp --> a device (e.g. daemon.id, "deviceName")
/// 6) *.service_acl.policy.sshnp --> a service ACL (e.g. service.id, client_group.id, "localhost:22")
Future<void> _populatePolicyCacheFromAtServer({
  required admin_v2.PolicyCache policyCache, // policy cache to populate
  // assuming that this is an authenticated atClient which has AtKeys that we need to go out and fetch.
  required AtClient atClient, 
  final String domainNamespace = admin_v2.PolicyCLIParamsDefaults.domainNamespaceV2, // e.g. 'policy_v2'
  final String baseNamespace = admin_v2.PolicyCLIParamsDefaults.baseNamespace, // e.g. 'sshnp'
}) async {
  if(atClient.getCurrentAtSign() == null) {
    throw Exception('atClient.getCurrentAtSign() is null. '
      'Be sure to authenticate atClient before passing it into this '
      'function.');
  }

  // Helper function to build policy regex patterns
  String buildPolicyRegex(String entityType) =>
      r'.*\.' '$entityType' r'\.' '$domainNamespace' r'\.' '$baseNamespace';

  // TODO: make these constans somewhere
  final String clientRegex = buildPolicyRegex('client');
  final String clientGroupRegex = buildPolicyRegex('client_group');
  final String clientGroupMemberRegex = buildPolicyRegex('client_group_member');
  final String daemonRegex = buildPolicyRegex('daemon');
  final String serviceRegex = buildPolicyRegex('service');
  final String serviceACLRegex = buildPolicyRegex('service_acl');

  final List<AtKey> clientAtKeys = await atClient.getAtKeys(
    sharedBy: atClient.getCurrentAtSign(),
    useRemoteAtServer: true,
    regex: clientRegex,
  );
  logger.info('Found ${clientAtKeys.length} Client atKeys on ${atClient.getCurrentAtSign()}\'s atServer.');

  final List<AtKey> clientGroupAtKeys = await atClient.getAtKeys(
    sharedBy: atClient.getCurrentAtSign(),
    useRemoteAtServer: true,
    regex: clientGroupRegex,
  );
  logger.info('Found ${clientGroupAtKeys.length} ClientGroup atKeys on ${atClient.getCurrentAtSign()}\'s atServer.');

  final List<AtKey> clientGroupMemberAtKeys = await atClient.getAtKeys(
    sharedBy: atClient.getCurrentAtSign(),
    useRemoteAtServer: true,
    regex: clientGroupMemberRegex,
  );
  logger.info('Found ${clientGroupMemberAtKeys.length} ClientGroupMember atKeys on ${atClient.getCurrentAtSign()}\'s atServer.');

  final List<AtKey> daemonAtKeys = await atClient.getAtKeys(
    sharedBy: atClient.getCurrentAtSign(),
    useRemoteAtServer: true,
    regex: daemonRegex,
  );
  logger.info('Found ${daemonAtKeys.length} Daemon atKeys on ${atClient.getCurrentAtSign()}\'s atServer.');

  final List<AtKey> serviceAtKeys = await atClient.getAtKeys(
    sharedBy: atClient.getCurrentAtSign(),
    useRemoteAtServer: true,
    regex: serviceRegex,
  );
  logger.info('Found ${serviceAtKeys.length} Service atKeys on ${atClient.getCurrentAtSign()}\'s atServer.');

  final List<AtKey> serviceACLAtKeys = await atClient.getAtKeys(
    sharedBy: atClient.getCurrentAtSign(),
    useRemoteAtServer: true,
    regex: serviceACLRegex,
  );
  logger.info('Found ${serviceACLAtKeys.length} ServiceACL atKeys on ${atClient.getCurrentAtSign()}\'s atServer.');
}

admin_v2.PolicyOperationHooks generatePolicyOperationHooks({
  required AtClient atClient,
  final String domainNamespace = admin_v2.PolicyCLIParamsDefaults.domainNamespaceV2, // e.g. 'policy_v2'
  final String baseNamespace = admin_v2.PolicyCLIParamsDefaults.baseNamespace, // e.g 'sshnp'
}) {
  admin_v2.PolicyOperationHooks policyOperationHooks = admin_v2.PolicyOperationHooks();
  
  policyOperationHooks.prePutClient = (admin_v2.Client client) async {
    final bool success = await atClient.put(
      AtKey()
        ..key = '${client.id}' // e.g. '1'
        ..namespace = 'client.$domainNamespace.$baseNamespace' // client.policy_v2.sshnp
        ..sharedBy = atClient.getCurrentAtSign(), // e.g. '@policy'
      jsonEncode(client.toJson()),
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = true
        ..useRemoteAtServer = true,
    );
    logger.info('Pre-put hook for Client: ${client.toJson()}, success: $success');
  };

  policyOperationHooks.prePutClientGroup = (admin_v2.ClientGroup clientGroup) async {
    final bool success = await atClient.put(
      AtKey()
        ..key = '${clientGroup.id}' // e.g. '1'
        ..namespace = 'client_group.$domainNamespace.$baseNamespace' // client_group.policy_v2.sshnp
        ..sharedBy = atClient.getCurrentAtSign(), // e.g. '@policy'
      jsonEncode(clientGroup.toJson()),
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = true
        ..useRemoteAtServer = true,
    );
    logger.info('Pre-put hook for ClientGroup: ${clientGroup.toJson()}, success: $success');
  };

  policyOperationHooks.prePutClientGroupMember = (admin_v2.ClientGroupMember clientGroupMember) async {
    final bool success = await atClient.put(
      AtKey()
        ..key = '${clientGroupMember.clientId}_${clientGroupMember.clientGroupId}' // e.g. '1_1'
        ..namespace = 'client_group_member.$domainNamespace.$baseNamespace' // client_group_member.policy_v2.sshnp
        ..sharedBy = atClient.getCurrentAtSign(), // e.g. '@policy'
      jsonEncode(clientGroupMember.toJson()),
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = true
        ..useRemoteAtServer = true,
    );
    logger.info('Pre-put hook for ClientGroupMember: ${clientGroupMember.toJson()}, success: $success');
  };

  policyOperationHooks.prePutDaemon = (admin_v2.Daemon daemon) async {
    final bool success = await atClient.put(
      AtKey()
        ..key = '${daemon.id}' // e.g. '1'
        ..namespace = 'daemon.$domainNamespace.$baseNamespace' // daemon.policy_v2.sshnp
        ..sharedBy = atClient.getCurrentAtSign(), // e.g. '@policy'
      jsonEncode(daemon.toJson()),
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = true
        ..useRemoteAtServer = true,
    );
    logger.info('Pre-put hook for Daemon: ${daemon.toJson()}, success: $success');
  };

  policyOperationHooks.prePutService = (admin_v2.Service service) async {
    final bool success = await atClient.put(
      AtKey()
        ..key = '${service.id}' // e.g. '1'
        ..namespace = 'service.$domainNamespace.$baseNamespace' // service.policy_v2.sshnp
        ..sharedBy = atClient.getCurrentAtSign(), // e.g. '@policy'
      jsonEncode(service.toJson()),
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = true
        ..useRemoteAtServer = true,
    );
    logger.info('Pre-put hook for Service: ${service.toJson()}, success: $success');
  };

  policyOperationHooks.prePutServiceACL = (admin_v2.ServiceACL serviceACL) async {
    final bool success = await atClient.put(
      AtKey()
        ..key = '${serviceACL.serviceId}_${serviceACL.clientGroupId}' // e.g. '1_1'
        ..namespace = 'service_acl.$domainNamespace.$baseNamespace' // service_acl.policy_v2.sshnp
        ..sharedBy = atClient.getCurrentAtSign(), // e.g. '@policy'
      jsonEncode(serviceACL.toJson()),
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = true
        ..useRemoteAtServer = true,
    );
    logger.info('Pre-put hook for ServiceACL: ${serviceACL.toJson()}, success: $success');
  };

  return policyOperationHooks;
}
