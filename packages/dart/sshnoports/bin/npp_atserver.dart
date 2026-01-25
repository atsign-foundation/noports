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

  final validPersistenceMethods = ['atserver', 'file', 'none'];
  if (!validPersistenceMethods.contains(p.persistenceMethod)) {
    stderr.writeln('Invalid persistence-method: ${p.persistenceMethod}');
    stderr.writeln('Valid options are: ${validPersistenceMethods.join(', ')}');
    exit(1);
  }

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

    // 1. Import default policyCache data
    final admin_v2.PolicyCache policyCache = await _populatePolicyCacheFromAtServer(
      atClient: atClient,
      domainNamespace: 'policy_v2', // TODO: make this a const somewhere
      baseNamespace: DefaultArgs.namespace,
    );


    final admin_v2.PolicyService policyService = admin_v2.PolicyService(
      policyOperationHooks: generatePolicyOperationHooksForAtServer(
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
/// 1) *.client.policy_v2.sshnp --> a client (e.g. "@alice", "Alice")
/// 2) *.client_group.policy_v2.sshnp --> a client group (e.g. client.id, "Atsign Engineers")
/// 3) *.client_group_member.policy_v2.sshnp --> maps client to a client group (e.g. client.id, client_group.id)
/// 4) *.daemon.policy_v2.sshnp --> a daemon (e.g. "@device")
/// 5) *.service.policy_v2.sshnp --> a device (e.g. daemon.id, "deviceName")
/// 6) *.service_acl.policy_v2.sshnp --> a service ACL (e.g. service.id, client_group.id, "localhost:22")
Future<admin_v2.PolicyCache> _populatePolicyCacheFromAtServer({
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

  final admin_v2.PolicyCache policyCache = admin_v2.PolicyCache();

  // Fetch all policy-related AtKeys in a single call
  final String allPolicyRegex = r'.*\.' '$domainNamespace' r'\.' '$baseNamespace';

  final List<AtKey> allPolicyAtKeys = await atClient.getAtKeys(
    sharedBy: atClient.getCurrentAtSign(),
    useRemoteAtServer: true,
    regex: allPolicyRegex,
  );

  logger.info('Found ${allPolicyAtKeys.length} policy AtKeys from atServer');

  // Counters for each entity type
  int clientsLoaded = 0;
  int clientGroupsLoaded = 0;
  int clientGroupMembersLoaded = 0;
  int daemonsLoaded = 0;
  int servicesLoaded = 0;
  int serviceACLsLoaded = 0;

  // Process all AtKeys in a single loop
  for (final AtKey atKey in allPolicyAtKeys) {
    try {
      // Determine entity type from namespace
      final String? namespace = atKey.namespace;
      if (namespace == null) {
        logger.warning('AtKey has null namespace: ${atKey.toString()}');
        continue;
      }

      // Fetch the value
      final AtValue atValue = await atClient.get(
        atKey,
        getRequestOptions: GetRequestOptions()..useRemoteAtServer = true
      );

      if (atValue.value == null) {
        logger.warning('Failed to fetch value for atKey: ${atKey.toString()}');
        continue;
      }

      final Map<String, dynamic> jsonData = jsonDecode(atValue.value);

      // Process based on entity type (check most specific first)
      if (namespace.startsWith('client_group_member.')) {
        final admin_v2.ClientGroupMember clientGroupMember = admin_v2.ClientGroupMember.fromJson(jsonData);
        policyCache.putClientGroupMember(clientGroupMember);
        logger.finer('Loaded ClientGroupMember into cache: id=${clientGroupMember.id}, clientId=${clientGroupMember.clientId}, clientGroupId=${clientGroupMember.clientGroupId}');
        clientGroupMembersLoaded++;
      } else if (namespace.startsWith('client_group.')) {
        final admin_v2.ClientGroup clientGroup = admin_v2.ClientGroup.fromJson(jsonData);
        policyCache.putClientGroup(clientGroup);
        logger.finer('Loaded ClientGroup into cache: id=${clientGroup.id}, name=${clientGroup.name}');
        clientGroupsLoaded++;
      } else if (namespace.startsWith('client.')) {
        final admin_v2.Client client = admin_v2.Client.fromJson(jsonData);
        policyCache.putClient(client);
        logger.finer('Loaded Client into cache: id=${client.id}, atSign=${client.atSign}, name=${client.name}');
        clientsLoaded++;
      } else if (namespace.startsWith('daemon.')) {
        final admin_v2.Daemon daemon = admin_v2.Daemon.fromJson(jsonData);
        policyCache.putDaemon(daemon);
        logger.finer('Loaded Daemon into cache: id=${daemon.id}, atSign=${daemon.atSign}');
        daemonsLoaded++;
      } else if (namespace.startsWith('service_acl.')) {
        final admin_v2.ServiceACL serviceACL = admin_v2.ServiceACL.fromJson(jsonData);
        policyCache.putServiceACL(serviceACL);
        logger.finer('Loaded ServiceACL into cache: id=${serviceACL.id}, serviceId=${serviceACL.serviceId}, clientGroupId=${serviceACL.clientGroupId}, permitOpen=${serviceACL.permitOpen}');
        serviceACLsLoaded++;
      } else if (namespace.startsWith('service.')) {
        final admin_v2.Service service = admin_v2.Service.fromJson(jsonData);
        policyCache.putService(service);
        logger.finer('Loaded Service into cache: id=${service.id}, daemonId=${service.daemonId}, deviceName=${service.deviceName}, deviceGroupName=${service.deviceGroupName}');
        servicesLoaded++;
      } else {
        logger.finer('Skipping atKey with unrecognized namespace: ${namespace}');
      }

    } catch (e, s) {
      logger.severe('Error loading entity from atKey ${atKey.toString()}: $e', e, s);
    }
  }

  // Log summary
  logger.info('Loaded $clientsLoaded Clients into cache');
  logger.info('Loaded $clientGroupsLoaded ClientGroups into cache');
  logger.info('Loaded $clientGroupMembersLoaded ClientGroupMembers into cache');
  logger.info('Loaded $daemonsLoaded Daemons into cache');
  logger.info('Loaded $servicesLoaded Services into cache');
  logger.info('Loaded $serviceACLsLoaded ServiceACLs into cache');

  return policyCache;
}


/// Populate the policy cache by fetching JSON files from a directory.
/// directoryPath ideally should be ~/.atsign/policy_v2/<@atsign>/*.json
/// 1) *_client.json
/// 2) *_client_group.json
/// 3) *_client_group_member.json
/// 4) *_daemon.json
/// 5) *_service.json
/// 6) *_service_acl.json
Future<admin_v2.PolicyCache> _generatePolicyCacheFromFiles({
  required String directoryPath, // directory path where JSON files are stored
}) async {
  // First, let's see if the directory exists
  final admin_v2.PolicyCache policyCache = admin_v2.PolicyCache();
  final directory = Directory(directoryPath);
  if(!(await directory.exists())) {
    logger.warning('Directory $directoryPath does not exist. Returning an empty PolicyCache()');
    return policyCache;
  }

  final List<FileSystemEntity> files = directory.listSync();
  logger.info('Found ${files.length} files in directory $directoryPath');
  for(final FileSystemEntity file in files) {
    logger.finer('Processing file: ${file.path}');
    logger.finer('File type: ${file.runtimeType}');
    if(file is File) {
      if(!file.path.endsWith('.json')) {
        logger.finer('Skipping non-JSON file: ${file.path}');
        continue;
      }
      final String fileName = file.uri.pathSegments.last;

      // Check for recognized suffixes (check most specific first)
      if(!fileName.endsWith('_client.json') &&
         !fileName.endsWith('_client_group.json') &&
         !fileName.endsWith('_client_group_member.json') &&
         !fileName.endsWith('_daemon.json') &&
         !fileName.endsWith('_service.json') &&
         !fileName.endsWith('_service_acl.json')) {
        logger.finer('Skipping file with unrecognized suffix: $fileName');
        continue;
      }

      logger.finer('Reading JSON file: $fileName');
      try {
        final String fileContent = await file.readAsString();
        final Map<String, dynamic> jsonData = jsonDecode(fileContent);

        // Check most specific suffixes first to avoid mismatches
        if(fileName.endsWith('_client_group_member.json')) {
          final admin_v2.ClientGroupMember clientGroupMember = admin_v2.ClientGroupMember.fromJson(jsonData);
          policyCache.putClientGroupMember(clientGroupMember);
          logger.finer('Loaded ClientGroupMember into cache: id=${clientGroupMember.id}, clientId=${clientGroupMember.clientId}, clientGroupId=${clientGroupMember.clientGroupId}');
        } else if(fileName.endsWith('_client_group.json')) {
          final admin_v2.ClientGroup clientGroup = admin_v2.ClientGroup.fromJson(jsonData);
          policyCache.putClientGroup(clientGroup);
          logger.finer('Loaded ClientGroup into cache: id=${clientGroup.id}, name=${clientGroup.name}');
        } else if(fileName.endsWith('_client.json')) {
          final admin_v2.Client client = admin_v2.Client.fromJson(jsonData);
          policyCache.putClient(client);
          logger.finer('Loaded Client into cache: id=${client.id}, atSign=${client.atSign}, name=${client.name}');
        } else if(fileName.endsWith('_service_acl.json')) {
          final admin_v2.ServiceACL serviceACL = admin_v2.ServiceACL.fromJson(jsonData);
          policyCache.putServiceACL(serviceACL);
          logger.finer('Loaded ServiceACL into cache: id=${serviceACL.id}, serviceId=${serviceACL.serviceId}, clientGroupId=${serviceACL.clientGroupId}, permitOpen=${serviceACL.permitOpen}');
        } else if(fileName.endsWith('_service.json')) {
          final admin_v2.Service service = admin_v2.Service.fromJson(jsonData);
          policyCache.putService(service);
          logger.finer('Loaded Service into cache: id=${service.id}, daemonId=${service.daemonId}, deviceName=${service.deviceName}, deviceGroupName=${service.deviceGroupName}');
        } else if(fileName.endsWith('_daemon.json')) {
          final admin_v2.Daemon daemon = admin_v2.Daemon.fromJson(jsonData);
          policyCache.putDaemon(daemon);
          logger.finer('Loaded Daemon into cache: id=${daemon.id}, atSign=${daemon.atSign}');
        }
      } catch (e, s) {
        logger.severe('Error reading or parsing file ${file.path}: $e', e, s);
        continue;
      }
    } else {
      logger.finer('Skipping non-file entity: ${file.path}');
    }
  }
  logger.info('Finished populating PolicyCache from files in $directoryPath');
  logger.info('Loaded ${policyCache.clients.length} Clients into cache');
  logger.info('Loaded ${policyCache.clientGroups.length} ClientGroups into cache');
  logger.info('Loaded ${policyCache.clientGroupMembers.length} ClientGroupMembers into cache');
  logger.info('Loaded ${policyCache.daemons.length} Daemons into cache');
  logger.info('Loaded ${policyCache.services.length} Services into cache');
  logger.info('Loaded ${policyCache.serviceACLs.length} ServiceACLs into cache');
  return policyCache;
}

admin_v2.PolicyOperationHooks generatePolicyOperationHooksForAtServer({
  required AtClient atClient,
  final String domainNamespace = admin_v2.PolicyCLIParamsDefaults.domainNamespaceV2, // e.g. 'policy_v2'
  final String baseNamespace = admin_v2.PolicyCLIParamsDefaults.baseNamespace, // e.g 'sshnp'
}) {
  admin_v2.PolicyOperationHooks policyOperationHooks = admin_v2.PolicyOperationHooks();

  policyOperationHooks.prePutClient = (admin_v2.Client client) async {
    final bool success = await atClient.put(
      AtKey()
        ..key = '${client.id}' // e.g. '1' (assigned before pre-hook is called)
        ..namespace = 'client.$domainNamespace.$baseNamespace' // client.policy_v2.sshnp
        ..sharedBy = atClient.getCurrentAtSign(), // e.g. '@policy'
      jsonEncode(client.toJson()),
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = true
        ..useRemoteAtServer = true,
    );
    if(!success) {
      throw Exception('Failed to put Client into atServer: ${client.toJson()}');
      // this would avoid putting it into the policy cache because persistence failed
    }
    logger.info('Pre-put hook for Client: ${client.toJson()}, success: $success');
  };

  policyOperationHooks.prePutClientGroup = (admin_v2.ClientGroup clientGroup) async {
    final bool success = await atClient.put(
      AtKey()
        ..key = '${clientGroup.id}' // e.g. '1' (assigned before pre-hook is called)
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
        ..key = '${clientGroupMember.id}' // e.g. '1' (assigned before pre-hook is called)
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
        ..key = '${daemon.id}' // e.g. '1' (assigned before pre-hook is called)
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
        ..key = '${service.id}' // e.g. '1' (assigned before pre-hook is called)
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
        ..key = '${serviceACL.id}' // e.g. '1' (assigned before pre-hook is called)
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

admin_v2.PolicyOperationHooks generatePolicyOperationHooksForFiles({
  required String directoryPath, // directory path where JSON files will be stored
}) {
  admin_v2.PolicyOperationHooks policyOperationHooks = admin_v2.PolicyOperationHooks();

  policyOperationHooks.prePutClient = (admin_v2.Client client) async {
    final file = File('$directoryPath/${client.id}_client.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(client.toJson()));
    logger.info('Pre-put hook for Client: wrote to ${file.path}');
  };

  policyOperationHooks.prePutClientGroup = (admin_v2.ClientGroup clientGroup) async {
    final file = File('$directoryPath/${clientGroup.id}_client_group.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(clientGroup.toJson()));
    logger.info('Pre-put hook for ClientGroup: wrote to ${file.path}');
  };

  policyOperationHooks.prePutClientGroupMember = (admin_v2.ClientGroupMember clientGroupMember) async {
    final file = File('$directoryPath/${clientGroupMember.id}_client_group_member.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(clientGroupMember.toJson()));
    logger.info('Pre-put hook for ClientGroupMember: wrote to ${file.path}');
  };

  policyOperationHooks.prePutDaemon = (admin_v2.Daemon daemon) async {
    final file = File('$directoryPath/${daemon.id}_daemon.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(daemon.toJson()));
    logger.info('Pre-put hook for Daemon: wrote to ${file.path}');
  };

  policyOperationHooks.prePutService = (admin_v2.Service service) async {
    final file = File('$directoryPath/${service.id}_service.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(service.toJson()));
    logger.info('Pre-put hook for Service: wrote to ${file.path}');
  };

  policyOperationHooks.prePutServiceACL = (admin_v2.ServiceACL serviceACL) async {
    final file = File('$directoryPath/${serviceACL.id}_service_acl.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(serviceACL.toJson()));
    logger.info('Pre-put hook for ServiceACL: wrote to ${file.path}');
  };

  return policyOperationHooks;
}
