import 'dart:convert';
import 'dart:io';

import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/npp.dart';
import 'package:sshnoports/src/create_at_client_cli.dart';
import 'package:sshnoports/src/print_version.dart';
import 'package:sshnoports/src/version.dart' as binaries_version;
import 'package:path/path.dart' as path;

late AtSignLogger logger;

Future<void> main(List<String> args) async {
  // 1. Parse if --help or --version was called
  try {
    if(NPPParams.argParser.parse(args)['help']) {
      print(NPPParams.argParser.usage);
      exit(0);
    }
    if(NPPParams.argParser.parse(args)['version']) {
      printVersion();
      exit(0);
    }
  } on ArgumentError catch (e) {
    stderr.writeln('Usage: \n${NPPParams.argParser.usage}\n');
    stderr.writeln(e.message);
    exit(1);
  } on FormatException catch (e) {
    stderr.writeln('Usage: \n${NPPParams.argParser.usage}\n');
    stderr.writeln(e.message);
    exit(1);
  } catch (err) {
    stderr.writeln('Usage: \n${NPPParams.argParser.usage}\n');
    stderr.writeln(err);
    exit(1);
  }

  // 2. Parse args
  final NPPParams nppParams;
  try {
    nppParams = NPPParams.fromArgs(args);
  } catch (err) {
    stderr.writeln('Usage: \n${NPPParams.argParser.usage}\n');
    stderr.writeln(err);
    exit(1);
  }

  // 3. Process args
  // 3a. --persistence-method
  final validPersistenceMethods = ['atserver', 'file', 'none']; // make these a const TODO
  if(!validPersistenceMethods.contains(nppParams.persistenceMethod)) {
    stderr.writeln('Invalid persistence-method: ${nppParams.persistenceMethod}');
    stderr.writeln('Valid options are: ${validPersistenceMethods.join(', ')}');
    exit(1);
  }

  // 3b. --key-file
  final File atKeysFile = File(nppParams.atKeysFilePath);
  if(!(await atKeysFile.exists())) {
    stderr.writeln('\n Unable to find .atKeys file : ${nppParams.atKeysFilePath}');
    exit(1);
  }

  // 3c. --verbose
  if(nppParams.verbose) {
    AtSignLogger.root_level = 'INFO';
  } else {
    AtSignLogger.root_level = 'SHOUT';
  }
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
  logger = AtSignLogger('npp');

  // 3d. Sanitize managerAllowList
  final Set<String> managerAllowList;
  if(nppParams.managerAllowList.trim().isEmpty) {
    managerAllowList = <String>{};
  } else {
    managerAllowList = nppParams.managerAllowList
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();
  }


  // 4. Set up AtClient instance
  final AtClient atClient;
  try {
    atClient = await createAtClientCli(
      atsign: nppParams.atSign,
      atKeysFilePath: nppParams.atKeysFilePath,
      rootDomain: nppParams.rootDomain,
      atServiceFactory: ServiceFactoryWithNoOpSyncService(),
      namespace: nppParams.baseNamespace,
      storagePath: nppParams.storagePath,
    );
  } catch (err) {
    stderr.writeln(err);
    exit(1);
  }

  // 5. Set up PolicyService
  // 5a. Set up PolicyCache and PolicyOperationHooks
  final PolicyCache policyCache;
  PolicyOperationHooks? policyOperationHooks;
  switch(nppParams.persistenceMethod) {
    case 'atserver': {
      logger.info('Using persistence method: "atserver"');
      policyCache = await _generatePolicyCacheFromAtServer(
        atClient: atClient,
        baseNamespace: nppParams.baseNamespace,
        domainNamespace: nppParams.domainNamespace,
      );

      policyOperationHooks = _generatePolicyOperationHooksForAtServer(
        atClient: atClient,
        baseNamespace: nppParams.baseNamespace,
        domainNamespace: nppParams.domainNamespace,
      );
      logger.info('Successfully loaded policy cache from atServer');
      break;
    }
    case 'file': {
      logger.info('Using persistence method: "file"');
      Directory policyDirectory;
      if(nppParams.policyDirectory == null) {
        policyDirectory = getDefaultPolicyDirectoryPath(
          baseDir: getHomeDirectory(),
          atSign: nppParams.atSign);
      } else {
        policyDirectory = Directory(nppParams.policyDirectory!);
      }

      // Create the directory if it doesn't exist
      if(!await policyDirectory.exists()) {
        logger.info('Policy directory does not exist. Creating: ${policyDirectory.path}');
        await policyDirectory.create(recursive: true);
        logger.info('Successfully created policy directory: ${policyDirectory.path}');
      }

      policyCache = await _generatePolicyCacheFromFiles(
        policyDirectory: policyDirectory,
      );
      policyOperationHooks = _generatePolicyOperationHooksForFiles(
        policyDirectory: policyDirectory,
      );
      logger.info('Successfully loaded policy cache from files in ${policyDirectory.path}');
    }
    case 'none': {
      logger.info('Using persistence method: "none". Instantiating empty PolicyCache');
      policyCache = PolicyCache();
    }
    default: {
      stderr.writeln('${nppParams.persistenceMethod} is not a valid type');
      exit(1);
    }
  }

  // 5b. Create PolicyService
  final PolicyService policyService = PolicyService(
    atClient: atClient,
    managerAllowList: managerAllowList,
    policyCache: policyCache,
    policyOperationHooks: policyOperationHooks,
    binariesVersion: binaries_version.packageVersion,
  );

  await policyService.start();
}

/// Generate policy cache by fetching AtKeys from the atServer.
/// 1) *.client.policy_v2.sshnp --> a client (e.g. "@alice", "Alice")
/// 2) *.client_group.policy_v2.sshnp --> a client group (e.g. client.id, "Atsign Engineers")
/// 3) *.client_group_member.policy_v2.sshnp --> maps client to a client group (e.g. client.id, client_group.id)
/// 4) *.daemon.policy_v2.sshnp --> a daemon (e.g. "@device")
/// 5) *.service.policy_v2.sshnp --> a device (e.g. daemon.id, "deviceName")
/// 6) *.service_acl.policy_v2.sshnp --> a service ACL (e.g. service.id, client_group.id, "localhost:22")
Future<PolicyCache> _generatePolicyCacheFromAtServer({
  // assuming that this is an authenticated atClient which has AtKeys that we need to go out and fetch.
  required final AtClient atClient,
  required final String baseNamespace,
  required final String domainNamespace,
}) async {
  if(atClient.getCurrentAtSign() == null) {
    throw Exception('atClient.getCurrentAtSign() is null. '
      'Be sure to authenticate atClient before passing it into this '
      'function.');
  }

  final PolicyCache policyCache = PolicyCache();

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
      // Extract entity type from the key field
      // Key format: {id}.{entity_type}.{domain_namespace}
      // Example: 1.client.npp
      final String? keyValue = atKey.key;
      if (keyValue == null || keyValue.isEmpty) {
        logger.warning('AtKey has null or empty key: ${atKey.toString()}');
        continue;
      }

      final List<String> keyParts = keyValue.split('.');
      if (keyParts.length < 2) {
        logger.warning('AtKey has unexpected key format: ${atKey.toString()}');
        continue;
      }

      // Entity type is the second-to-last part (before domain namespace)
      // For "1.client.npp", parts are [1, client, npp], so entity type is at index 1
      final String entityType = keyParts[keyParts.length - 2];

      logger.info('Processing AtKey: ${atKey.toString()}, entityType: $entityType');

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
      if (entityType == 'client_group_member') {
        final ClientGroupMember clientGroupMember = ClientGroupMember.fromJson(jsonData);
        policyCache.putClientGroupMember(clientGroupMember);
        logger.info('Loaded ClientGroupMember into cache: id=${clientGroupMember.id}, clientId=${clientGroupMember.clientId}, clientGroupId=${clientGroupMember.clientGroupId}');
        clientGroupMembersLoaded++;
      } else if (entityType == 'client_group') {
        final ClientGroup clientGroup = ClientGroup.fromJson(jsonData);
        policyCache.putClientGroup(clientGroup);
        logger.info('Loaded ClientGroup into cache: id=${clientGroup.id}, name=${clientGroup.name}');
        clientGroupsLoaded++;
      } else if (entityType == 'client') {
        final Client client = Client.fromJson(jsonData);
        policyCache.putClient(client);
        logger.info('Loaded Client into cache: id=${client.id}, atSign=${client.atSign}, name=${client.name}');
        clientsLoaded++;
      } else if (entityType == 'daemon') {
        final Daemon daemon = Daemon.fromJson(jsonData);
        policyCache.putDaemon(daemon);
        logger.info('Loaded Daemon into cache: id=${daemon.id}, atSign=${daemon.atSign}');
        daemonsLoaded++;
      } else if (entityType == 'service_acl') {
        final ServiceACL serviceACL = ServiceACL.fromJson(jsonData);
        policyCache.putServiceACL(serviceACL);
        logger.info('Loaded ServiceACL into cache: id=${serviceACL.id}, serviceId=${serviceACL.serviceId}, clientGroupId=${serviceACL.clientGroupId}, permitOpen=${serviceACL.permitOpen}');
        serviceACLsLoaded++;
      } else if (entityType == 'service') {
        final Service service = Service.fromJson(jsonData);
        policyCache.putService(service);
        logger.info('Loaded Service into cache: id=${service.id}, daemonId=${service.daemonId}, deviceName=${service.deviceName}, deviceGroupName=${service.deviceGroupName}');
        servicesLoaded++;
      } else {
        logger.warning('Skipping atKey with unrecognized entity type: $entityType (atKey: ${atKey.toString()})');
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

/// Generate policy cache by fetching JSON files from a directory.
/// directoryPath ideally should be ~/.atsign/npp/<@atsign>/*.json
/// 1) *_client.json
/// 2) *_client_group.json
/// 3) *_client_group_member.json
/// 4) *_daemon.json
/// 5) *_service.json
/// 6) *_service_acl.json
Future<PolicyCache> _generatePolicyCacheFromFiles({
  required Directory policyDirectory, // directory path where JSON files are stored e.g. "~/.atsign/npp/@jeremy"
}) async {
  final PolicyCache policyCache = PolicyCache();
  if(!(await policyDirectory.exists())) {
    logger.info('Directory $policyDirectory does not exist. Returning an empty PolicyCache()');
    return policyCache;
  }

  final List<FileSystemEntity> files = policyDirectory.listSync();
  if(files.isEmpty) {
    logger.info('No files found in directory $policyDirectory. Starting with empty PolicyCache()');
  } else {
    logger.info('Found ${files.length} files in directory $policyDirectory');
  }
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
          final ClientGroupMember clientGroupMember = ClientGroupMember.fromJson(jsonData);
          policyCache.putClientGroupMember(clientGroupMember);
          logger.finer('Loaded ClientGroupMember into cache: id=${clientGroupMember.id}, clientId=${clientGroupMember.clientId}, clientGroupId=${clientGroupMember.clientGroupId}');
        } else if(fileName.endsWith('_client_group.json')) {
          final ClientGroup clientGroup = ClientGroup.fromJson(jsonData);
          policyCache.putClientGroup(clientGroup);
          logger.finer('Loaded ClientGroup into cache: id=${clientGroup.id}, name=${clientGroup.name}');
        } else if(fileName.endsWith('_client.json')) {
          final Client client = Client.fromJson(jsonData);
          policyCache.putClient(client);
          logger.finer('Loaded Client into cache: id=${client.id}, atSign=${client.atSign}, name=${client.name}');
        } else if(fileName.endsWith('_service_acl.json')) {
          final ServiceACL serviceACL = ServiceACL.fromJson(jsonData);
          policyCache.putServiceACL(serviceACL);
          logger.finer('Loaded ServiceACL into cache: id=${serviceACL.id}, serviceId=${serviceACL.serviceId}, clientGroupId=${serviceACL.clientGroupId}, permitOpen=${serviceACL.permitOpen}');
        } else if(fileName.endsWith('_service.json')) {
          final Service service = Service.fromJson(jsonData);
          policyCache.putService(service);
          logger.finer('Loaded Service into cache: id=${service.id}, daemonId=${service.daemonId}, deviceName=${service.deviceName}, deviceGroupName=${service.deviceGroupName}');
        } else if(fileName.endsWith('_daemon.json')) {
          final Daemon daemon = Daemon.fromJson(jsonData);
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
  logger.info('Finished populating PolicyCache from files in ${policyDirectory.path}');
  logger.info('Loaded ${policyCache.clients.length} Clients into cache');
  logger.info('Loaded ${policyCache.clientGroups.length} ClientGroups into cache');
  logger.info('Loaded ${policyCache.clientGroupMembers.length} ClientGroupMembers into cache');
  logger.info('Loaded ${policyCache.daemons.length} Daemons into cache');
  logger.info('Loaded ${policyCache.services.length} Services into cache');
  logger.info('Loaded ${policyCache.serviceACLs.length} ServiceACLs into cache');
  return policyCache;
}

PolicyOperationHooks _generatePolicyOperationHooksForAtServer({
  required final AtClient atClient,
  required final String domainNamespace, // e.g. 'policy_v2'
  required final String baseNamespace, // e.g 'sshnp'
}) {
  PolicyOperationHooks policyOperationHooks = PolicyOperationHooks();

  policyOperationHooks.prePutClient = (Client client) async {
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
      // this would avoid putting it into the policy cache because persistence failed
      throw Exception('Failed to put Client into atServer: ${client.toJson()}');
    }
    logger.info('Pre-put hook for Client: ${client.toJson()}, success: $success');
  };

  policyOperationHooks.prePutClientGroup = (ClientGroup clientGroup) async {
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
    if(!success) {
      throw Exception('Failed to put ClientGroup into atServer: ${clientGroup.toJson()}');
    }
    logger.info('Pre-put hook for ClientGroup: ${clientGroup.toJson()}, success: $success');
  };

  policyOperationHooks.prePutClientGroupMember = (ClientGroupMember clientGroupMember) async {
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
    if(!success) {
      throw Exception('Failed to put ClientGroupMember into atServer: ${clientGroupMember.toJson()}');
    }
    logger.info('Pre-put hook for ClientGroupMember: ${clientGroupMember.toJson()}, success: $success');
  };

  policyOperationHooks.prePutDaemon = (Daemon daemon) async {
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
    if(!success) {
      throw Exception('Failed to put Daemon into atServer: ${daemon.toJson()}');
    }
    logger.info('Pre-put hook for Daemon: ${daemon.toJson()}, success: $success');
  };

  policyOperationHooks.prePutService = (Service service) async {
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
    if(!success) {
      throw Exception('Failed to put Service into atServer: ${service.toJson()}');
    }
    logger.info('Pre-put hook for Service: ${service.toJson()}, success: $success');
  };

  policyOperationHooks.prePutServiceACL = (ServiceACL serviceACL) async {
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
    if(!success) {
      throw Exception('Failed to put ServiceACL into atServer: ${serviceACL.toJson()}');
    }
    logger.info('Pre-put hook for ServiceACL: ${serviceACL.toJson()}, success: $success');
  };

  return policyOperationHooks;
}

PolicyOperationHooks _generatePolicyOperationHooksForFiles({
  required Directory policyDirectory,
}) {

  if(!(policyDirectory.existsSync())) {
    stderr.writeln('${policyDirectory.path} directory was not found.');
    exit(1);
  }

  final String directoryPath = policyDirectory.path;

  PolicyOperationHooks policyOperationHooks = PolicyOperationHooks();

  policyOperationHooks.prePutClient = (Client client) async {
    final file = File('$directoryPath/${client.id}_client.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(client.toJson()));
    logger.info('Pre-put hook for Client: wrote to ${file.path}');
  };

  policyOperationHooks.prePutClientGroup = (ClientGroup clientGroup) async {
    final file = File('$directoryPath/${clientGroup.id}_client_group.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(clientGroup.toJson()));
    logger.info('Pre-put hook for ClientGroup: wrote to ${file.path}');
  };

  policyOperationHooks.prePutClientGroupMember = (ClientGroupMember clientGroupMember) async {
    final file = File('$directoryPath/${clientGroupMember.id}_client_group_member.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(clientGroupMember.toJson()));
    logger.info('Pre-put hook for ClientGroupMember: wrote to ${file.path}');
  };

  policyOperationHooks.prePutDaemon = (Daemon daemon) async {
    final file = File('$directoryPath/${daemon.id}_daemon.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(daemon.toJson()));
    logger.info('Pre-put hook for Daemon: wrote to ${file.path}');
  };

  policyOperationHooks.prePutService = (Service service) async {
    final file = File('$directoryPath/${service.id}_service.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(service.toJson()));
    logger.info('Pre-put hook for Service: wrote to ${file.path}');
  };

  policyOperationHooks.prePutServiceACL = (ServiceACL serviceACL) async {
    final file = File('$directoryPath/${serviceACL.id}_service_acl.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(serviceACL.toJson()));
    logger.info('Pre-put hook for ServiceACL: wrote to ${file.path}');
  };

  return policyOperationHooks;
}

Directory getDefaultPolicyDirectoryPath({
  required final String atSign,
  String? baseDir,
}) {
  if(baseDir == null) {
    String? homeDirectory = getHomeDirectory();
    if(homeDirectory == null) {
      stderr.writeln('homeDirectory could not be resolved');
      exit(1);
    }
    baseDir = homeDirectory;
  }

  // append /.atsign/npp/<atsign>
  return Directory(path.normalize(
    '$baseDir'
    '/.atsign'
    '/npp'
    '/$atSign').replaceAll('/', Platform.pathSeparator));
}

