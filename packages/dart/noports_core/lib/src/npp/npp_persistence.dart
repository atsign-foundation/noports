import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:meta/meta.dart';

import 'package:noports_core/src/common/validation_utils.dart';

import './models.dart';
import './npp_cache.dart';
import './npp_operation_hooks.dart';

final AtSignLogger _logger = AtSignLogger('npp');

/// The logger the rule loaders and hooks write to.
@visibleForTesting
AtSignLogger get nppPersistenceLogger => _logger;

/// The kinds of rule a policy file name can end with, as `<id>_<kind>.json`.
const List<String> _fileKinds = [
  'client',
  'client_group',
  'client_group_member',
  'daemon',
  'service',
  'service_acl',
];

/// Whether [name], the part of a stored rule's key or file name before its
/// kind, is the id in [json]. [folded] compares them folded, as atServer
/// keys are; file names are compared as they are, as the delete hook names
/// the file.
bool _carriesId(
  String name,
  Map<String, dynamic> json, {
  required bool folded,
}) {
  final Object? id = json['id'];
  if (id is! String) {
    return false;
  }
  return folded ? id.toLowerCase() == name.toLowerCase() : id == name;
}

/// Removes from [nppCache] each rule naming a rule it doesn't hold, with a
/// warning for each.
void _removeRulesNamingMissing(NppCache nppCache) {
  for (final (kind, rule, missing) in nppCache.removeRulesNamingMissing()) {
    _logger.warning(
      'Not loading $kind with id ${rule.id}: it names '
      '${missing.join(' and ')}, which is not loaded',
    );
  }
}

/// Generate policy cache by fetching AtKeys from the atServer.
/// 1) *.client.policy_v2.sshnp --> a client (e.g. "@alice", "Alice")
/// 2) *.client_group.policy_v2.sshnp --> a client group (e.g. client.id, "Atsign Engineers")
/// 3) *.client_group_member.policy_v2.sshnp --> maps client to a client group (e.g. client.id, client_group.id)
/// 4) *.daemon.policy_v2.sshnp --> a daemon (e.g. "@device")
/// 5) *.service.policy_v2.sshnp --> a device (e.g. daemon.id, "deviceName")
/// 6) *.service_acl.policy_v2.sshnp --> a service ACL (e.g. service.id, client_group.id, "localhost:22")
Future<NppCache> nppCacheFromAtServer({
  // assuming that this is an authenticated atClient which has AtKeys that we need to go out and fetch.
  required final AtClient atClient,
  required final String baseNamespace,
  required final String domainNamespace,
}) async {
  if (atClient.getCurrentAtSign() == null) {
    throw Exception(
      'atClient.getCurrentAtSign() is null. '
      'Be sure to authenticate atClient before passing it into this '
      'function.',
    );
  }

  final NppCache nppCache = NppCache();

  // Fetch all policy-related AtKeys in a single call
  final String allPolicyRegex =
      r'.*\.'
      '$domainNamespace'
      r'\.'
      '$baseNamespace';

  final List<AtKey> allPolicyAtKeys = await atClient.getAtKeys(
    sharedBy: atClient.getCurrentAtSign(),
    useRemoteAtServer: true,
    regex: allPolicyRegex,
  );

  _logger.info('Found ${allPolicyAtKeys.length} policy AtKeys from atServer');

  for (final AtKey atKey in allPolicyAtKeys) {
    try {
      if (!sameAtsign(atKey.sharedBy, atClient.getCurrentAtSign()) ||
          atKey.sharedWith != null ||
          atKey.metadata.isPublic) {
        _logger.warning(
          'Not loading ${atKey.toString()}: npp loads only keys the policy '
          'atSign owns, unshared',
        );
        continue;
      }
      final String keyValue = atKey.key;
      if (keyValue.isEmpty) {
        _logger.warning('AtKey has null or empty key: ${atKey.toString()}');
        continue;
      }

      final List<String> keyParts = keyValue.split('.');
      if (keyParts.length < 2) {
        _logger.warning('AtKey has unexpected key format: ${atKey.toString()}');
        continue;
      }

      final String entityType = keyParts[keyParts.length - 2]; // e.g. "client"

      _logger.finer(
        'Processing AtKey: ${atKey.toString()}, entityType: $entityType',
      );

      final AtValue atValue = await atClient.get(
        atKey,
        getRequestOptions: GetRequestOptions()..useRemoteAtServer = true,
      );

      if (atValue.value == null) {
        _logger.warning('Failed to fetch value for atKey: ${atKey.toString()}');
        continue;
      }

      final Map<String, dynamic> jsonData = jsonDecode(atValue.value);
      final String name = keyParts.sublist(0, keyParts.length - 2).join('.');
      if (!_carriesId(name, jsonData, folded: true)) {
        _logger.warning(
          'Not loading ${atKey.toString()}: its key does not carry its id '
          '${jsonData['id']}',
        );
        continue;
      }

      if (entityType == 'client_group_member') {
        final ClientGroupMember clientGroupMember = ClientGroupMember.fromJson(
          jsonData,
        );
        nppCache.putClientGroupMember(clientGroupMember);
        _logger.finer(
          'Loaded ClientGroupMember into cache: id=${clientGroupMember.id}, clientId=${clientGroupMember.clientId}, clientGroupId=${clientGroupMember.clientGroupId}',
        );
      } else if (entityType == 'client_group') {
        final ClientGroup clientGroup = ClientGroup.fromJson(jsonData);
        nppCache.putClientGroup(clientGroup);
        _logger.finer(
          'Loaded ClientGroup into cache: id=${clientGroup.id}, name=${clientGroup.name}',
        );
      } else if (entityType == 'client') {
        final Client client = Client.fromJson(jsonData);
        nppCache.putClient(client);
        _logger.finer(
          'Loaded Client into cache: id=${client.id}, atSign=${client.atSign}, name=${client.name}',
        );
      } else if (entityType == 'daemon') {
        final Daemon daemon = Daemon.fromJson(jsonData);
        nppCache.putDaemon(daemon);
        _logger.finer(
          'Loaded Daemon into cache: id=${daemon.id}, atSign=${daemon.atSign}',
        );
      } else if (entityType == 'service_acl') {
        final ServiceACL serviceACL = ServiceACL.fromJson(jsonData);
        nppCache.putServiceACL(serviceACL);
        _logger.finer(
          'Loaded ServiceACL into cache: id=${serviceACL.id}, serviceId=${serviceACL.serviceId}, clientGroupId=${serviceACL.clientGroupId}, permitOpen=${serviceACL.permitOpen}',
        );
      } else if (entityType == 'service') {
        final Service service = Service.fromJson(jsonData);
        nppCache.putService(service);
        _logger.finer(
          'Loaded Service into cache: id=${service.id}, daemonId=${service.daemonId}, deviceName=${service.deviceName}, deviceGroupName=${service.deviceGroupName}',
        );
      } else {
        _logger.warning(
          'Skipping atKey with unrecognized entity type: $entityType (atKey: ${atKey.toString()})',
        );
      }
    } catch (e, s) {
      _logger.severe(
        'Error loading entity from atKey ${atKey.toString()}: $e',
        e,
        s,
      );
    }
  }

  _removeRulesNamingMissing(nppCache);
  _logger.info('Loaded ${nppCache.clients.length} Clients into cache');
  _logger.info(
    'Loaded ${nppCache.clientGroups.length} ClientGroups into cache',
  );
  _logger.info(
    'Loaded ${nppCache.clientGroupMembers.length} ClientGroupMembers into cache',
  );
  _logger.info('Loaded ${nppCache.daemons.length} Daemons into cache');
  _logger.info('Loaded ${nppCache.services.length} Services into cache');
  _logger.info('Loaded ${nppCache.serviceACLs.length} ServiceACLs into cache');

  return nppCache;
}

/// Generate policy cache by fetching JSON files from a directory.
/// directoryPath ideally should be ~/.atsign/npp/<@atsign>/*.json
/// 1) *_client.json
/// 2) *_client_group.json
/// 3) *_client_group_member.json
/// 4) *_daemon.json
/// 5) *_service.json
/// 6) *_service_acl.json
Future<NppCache> nppCacheFromFiles({
  required Directory
  policyDirectory, // directory path where JSON files are stored e.g. "~/.atsign/npp/@jeremy"
}) async {
  final NppCache nppCache = NppCache();
  if (!(await policyDirectory.exists())) {
    _logger.info(
      'Directory $policyDirectory does not exist. Returning an empty NppCache()',
    );
    return nppCache;
  }

  final List<FileSystemEntity> files = policyDirectory.listSync();
  if (files.isEmpty) {
    _logger.info(
      'No files found in directory $policyDirectory. Starting with empty NppCache()',
    );
  } else {
    _logger.info('Found ${files.length} files in directory $policyDirectory');
  }
  for (final FileSystemEntity file in files) {
    _logger.finer('Processing file: ${file.path}');
    _logger.finer('File type: ${file.runtimeType}');
    if (file is File) {
      if (!file.path.endsWith('.json')) {
        _logger.finer('Skipping non-JSON file: ${file.path}');
        continue;
      }
      final String fileName = file.uri.pathSegments.last;

      // Check for recognized suffixes (check most specific first)
      if (!fileName.endsWith('_client.json') &&
          !fileName.endsWith('_client_group.json') &&
          !fileName.endsWith('_client_group_member.json') &&
          !fileName.endsWith('_daemon.json') &&
          !fileName.endsWith('_service.json') &&
          !fileName.endsWith('_service_acl.json')) {
        _logger.finer('Skipping file with unrecognized suffix: $fileName');
        continue;
      }

      _logger.finer('Reading JSON file: $fileName');
      try {
        final String fileContent = await file.readAsString();
        final Map<String, dynamic> jsonData = jsonDecode(fileContent);
        final String suffix = _fileKinds
            .map((kind) => '_$kind.json')
            .firstWhere(fileName.endsWith);
        final String name = fileName.substring(
          0,
          fileName.length - suffix.length,
        );
        if (!_carriesId(name, jsonData, folded: false)) {
          _logger.warning(
            'Not loading ${file.path}: its name does not carry its id '
            '${jsonData['id']}',
          );
          continue;
        }

        // Check most specific suffixes first to avoid mismatches
        if (fileName.endsWith('_client_group_member.json')) {
          final ClientGroupMember clientGroupMember =
              ClientGroupMember.fromJson(jsonData);
          nppCache.putClientGroupMember(clientGroupMember);
          _logger.finer(
            'Loaded ClientGroupMember into cache: id=${clientGroupMember.id}, clientId=${clientGroupMember.clientId}, clientGroupId=${clientGroupMember.clientGroupId}',
          );
        } else if (fileName.endsWith('_client_group.json')) {
          final ClientGroup clientGroup = ClientGroup.fromJson(jsonData);
          nppCache.putClientGroup(clientGroup);
          _logger.finer(
            'Loaded ClientGroup into cache: id=${clientGroup.id}, name=${clientGroup.name}',
          );
        } else if (fileName.endsWith('_client.json')) {
          final Client client = Client.fromJson(jsonData);
          nppCache.putClient(client);
          _logger.finer(
            'Loaded Client into cache: id=${client.id}, atSign=${client.atSign}, name=${client.name}',
          );
        } else if (fileName.endsWith('_service_acl.json')) {
          final ServiceACL serviceACL = ServiceACL.fromJson(jsonData);
          nppCache.putServiceACL(serviceACL);
          _logger.finer(
            'Loaded ServiceACL into cache: id=${serviceACL.id}, serviceId=${serviceACL.serviceId}, clientGroupId=${serviceACL.clientGroupId}, permitOpen=${serviceACL.permitOpen}',
          );
        } else if (fileName.endsWith('_service.json')) {
          final Service service = Service.fromJson(jsonData);
          nppCache.putService(service);
          _logger.finer(
            'Loaded Service into cache: id=${service.id}, daemonId=${service.daemonId}, deviceName=${service.deviceName}, deviceGroupName=${service.deviceGroupName}',
          );
        } else if (fileName.endsWith('_daemon.json')) {
          final Daemon daemon = Daemon.fromJson(jsonData);
          nppCache.putDaemon(daemon);
          _logger.finer(
            'Loaded Daemon into cache: id=${daemon.id}, atSign=${daemon.atSign}',
          );
        }
      } catch (e, s) {
        _logger.severe('Error reading or parsing file ${file.path}: $e', e, s);
        continue;
      }
    } else {
      _logger.finer('Skipping non-file entity: ${file.path}');
    }
  }
  _removeRulesNamingMissing(nppCache);
  _logger.info(
    'Finished populating NppCache from files in ${policyDirectory.path}',
  );
  _logger.info('Loaded ${nppCache.clients.length} Clients into cache');
  _logger.info(
    'Loaded ${nppCache.clientGroups.length} ClientGroups into cache',
  );
  _logger.info(
    'Loaded ${nppCache.clientGroupMembers.length} ClientGroupMembers into cache',
  );
  _logger.info('Loaded ${nppCache.daemons.length} Daemons into cache');
  _logger.info('Loaded ${nppCache.services.length} Services into cache');
  _logger.info('Loaded ${nppCache.serviceACLs.length} ServiceACLs into cache');

  return nppCache;
}

NppOperationHooks nppOperationHooksForAtServer({
  required final AtClient atClient,
  required final String domainNamespace, // e.g. 'policy_v2'
  required final String baseNamespace, // e.g 'sshnp'
}) {
  NppOperationHooks nppOperationHooks = NppOperationHooks();

  nppOperationHooks.prePutClient = (Client client) async {
    final bool success = await atClient.put(
      AtKey()
        ..key =
            '${client.id}' // assigned before pre-hook is called
        ..namespace =
            'client.$domainNamespace.$baseNamespace' // client.policy_v2.sshnp
        ..sharedBy = atClient.getCurrentAtSign(), // e.g. '@policy'
      jsonEncode(client.toJson()),
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = true
        ..useRemoteAtServer = true,
    );
    if (!success) {
      // this would avoid putting it into the policy cache because persistence failed
      throw Exception('Failed to put Client into atServer: ${client.toJson()}');
    }
    _logger.info(
      'Pre-put hook for Client: ${client.toJson()}, success: $success',
    );
  };

  nppOperationHooks.prePutClientGroup = (ClientGroup clientGroup) async {
    final bool success = await atClient.put(
      AtKey()
        ..key =
            '${clientGroup.id}' // assigned before pre-hook is called
        ..namespace =
            'client_group.$domainNamespace.$baseNamespace' // client_group.policy_v2.sshnp
        ..sharedBy = atClient.getCurrentAtSign(), // e.g. '@policy'
      jsonEncode(clientGroup.toJson()),
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = true
        ..useRemoteAtServer = true,
    );
    if (!success) {
      throw Exception(
        'Failed to put ClientGroup into atServer: ${clientGroup.toJson()}',
      );
    }
    _logger.info(
      'Pre-put hook for ClientGroup: ${clientGroup.toJson()}, success: $success',
    );
  };

  nppOperationHooks
      .prePutClientGroupMember = (ClientGroupMember clientGroupMember) async {
    final bool success = await atClient.put(
      AtKey()
        ..key =
            '${clientGroupMember.id}' // assigned before pre-hook is called
        ..namespace =
            'client_group_member.$domainNamespace.$baseNamespace' // client_group_member.policy_v2.sshnp
        ..sharedBy = atClient.getCurrentAtSign(), // e.g. '@policy'
      jsonEncode(clientGroupMember.toJson()),
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = true
        ..useRemoteAtServer = true,
    );
    if (!success) {
      throw Exception(
        'Failed to put ClientGroupMember into atServer: ${clientGroupMember.toJson()}',
      );
    }
    _logger.info(
      'Pre-put hook for ClientGroupMember: ${clientGroupMember.toJson()}, success: $success',
    );
  };

  nppOperationHooks.prePutDaemon = (Daemon daemon) async {
    final bool success = await atClient.put(
      AtKey()
        ..key =
            '${daemon.id}' // assigned before pre-hook is called
        ..namespace =
            'daemon.$domainNamespace.$baseNamespace' // daemon.policy_v2.sshnp
        ..sharedBy = atClient.getCurrentAtSign(), // e.g. '@policy'
      jsonEncode(daemon.toJson()),
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = true
        ..useRemoteAtServer = true,
    );
    if (!success) {
      throw Exception('Failed to put Daemon into atServer: ${daemon.toJson()}');
    }
    _logger.info(
      'Pre-put hook for Daemon: ${daemon.toJson()}, success: $success',
    );
  };

  nppOperationHooks.prePutService = (Service service) async {
    final bool success = await atClient.put(
      AtKey()
        ..key =
            '${service.id}' // assigned before pre-hook is called
        ..namespace =
            'service.$domainNamespace.$baseNamespace' // service.policy_v2.sshnp
        ..sharedBy = atClient.getCurrentAtSign(), // e.g. '@policy'
      jsonEncode(service.toJson()),
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = true
        ..useRemoteAtServer = true,
    );
    if (!success) {
      throw Exception(
        'Failed to put Service into atServer: ${service.toJson()}',
      );
    }
    _logger.info(
      'Pre-put hook for Service: ${service.toJson()}, success: $success',
    );
  };

  nppOperationHooks.prePutServiceACL = (ServiceACL serviceACL) async {
    final bool success = await atClient.put(
      AtKey()
        ..key =
            '${serviceACL.id}' // assigned before pre-hook is called
        ..namespace =
            'service_acl.$domainNamespace.$baseNamespace' // service_acl.policy_v2.sshnp
        ..sharedBy = atClient.getCurrentAtSign(), // e.g. '@policy'
      jsonEncode(serviceACL.toJson()),
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = true
        ..useRemoteAtServer = true,
    );
    if (!success) {
      throw Exception(
        'Failed to put ServiceACL into atServer: ${serviceACL.toJson()}',
      );
    }
    _logger.info(
      'Pre-put hook for ServiceACL: ${serviceACL.toJson()}, success: $success',
    );
  };

  /// Deletes the atServer copy of the [kind] rule [id] (e.g. `client`), the
  /// key its pre-put hook wrote, so a deleted rule isn't loaded again.
  Future<void> deleteKey(String kind, String? id) async {
    final bool success = await atClient.delete(
      AtKey()
        ..key = '$id'
        ..namespace = '$kind.$domainNamespace.$baseNamespace'
        ..sharedBy = atClient.getCurrentAtSign(),
      deleteRequestOptions: DeleteRequestOptions()..useRemoteAtServer = true,
    );
    if (!success) {
      throw Exception('Failed to delete $kind $id from atServer');
    }
    _logger.info('Pre-delete hook for $kind $id, success: $success');
  }

  nppOperationHooks.preDeleteClient = (Client client) =>
      deleteKey('client', client.id);
  nppOperationHooks.preDeleteClientGroup = (ClientGroup clientGroup) =>
      deleteKey('client_group', clientGroup.id);
  nppOperationHooks.preDeleteClientGroupMember =
      (ClientGroupMember clientGroupMember) =>
          deleteKey('client_group_member', clientGroupMember.id);
  nppOperationHooks.preDeleteDaemon = (Daemon daemon) =>
      deleteKey('daemon', daemon.id);
  nppOperationHooks.preDeleteService = (Service service) =>
      deleteKey('service', service.id);
  nppOperationHooks.preDeleteServiceACL = (ServiceACL serviceACL) =>
      deleteKey('service_acl', serviceACL.id);
  return nppOperationHooks;
}

NppOperationHooks nppOperationHooksForFiles({
  required Directory policyDirectory,
}) {
  if (!(policyDirectory.existsSync())) {
    throw FileSystemException('Directory was not found', policyDirectory.path);
  }

  final String directoryPath = policyDirectory.path;

  NppOperationHooks nppOperationHooks = NppOperationHooks();

  nppOperationHooks.prePutClient = (Client client) async {
    final file = File('$directoryPath/${client.id}_client.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(client.toJson()));
    _logger.info('Pre-put hook for Client: wrote to ${file.path}');
  };

  nppOperationHooks.prePutClientGroup = (ClientGroup clientGroup) async {
    final file = File('$directoryPath/${clientGroup.id}_client_group.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(clientGroup.toJson()));
    _logger.info('Pre-put hook for ClientGroup: wrote to ${file.path}');
  };

  nppOperationHooks
      .prePutClientGroupMember = (ClientGroupMember clientGroupMember) async {
    final file = File(
      '$directoryPath/${clientGroupMember.id}_client_group_member.json',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(clientGroupMember.toJson()));
    _logger.info('Pre-put hook for ClientGroupMember: wrote to ${file.path}');
  };

  nppOperationHooks.prePutDaemon = (Daemon daemon) async {
    final file = File('$directoryPath/${daemon.id}_daemon.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(daemon.toJson()));
    _logger.info('Pre-put hook for Daemon: wrote to ${file.path}');
  };

  nppOperationHooks.prePutService = (Service service) async {
    final file = File('$directoryPath/${service.id}_service.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(service.toJson()));
    _logger.info('Pre-put hook for Service: wrote to ${file.path}');
  };

  nppOperationHooks.prePutServiceACL = (ServiceACL serviceACL) async {
    final file = File('$directoryPath/${serviceACL.id}_service_acl.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(serviceACL.toJson()));
    _logger.info('Pre-put hook for ServiceACL: wrote to ${file.path}');
  };

  /// Deletes [fileName] from the policy directory. A file already gone is
  /// fine, so a failed delete can be retried.
  Future<void> deleteFile(String fileName) async {
    final file = File('$directoryPath/$fileName');
    if (await file.exists()) {
      await file.delete();
    }
    _logger.info('Pre-delete hook: removed ${file.path}');
  }

  nppOperationHooks.preDeleteClient = (Client client) =>
      deleteFile('${client.id}_client.json');
  nppOperationHooks.preDeleteClientGroup = (ClientGroup clientGroup) =>
      deleteFile('${clientGroup.id}_client_group.json');
  nppOperationHooks.preDeleteClientGroupMember =
      (ClientGroupMember clientGroupMember) =>
          deleteFile('${clientGroupMember.id}_client_group_member.json');
  nppOperationHooks.preDeleteDaemon = (Daemon daemon) =>
      deleteFile('${daemon.id}_daemon.json');
  nppOperationHooks.preDeleteService = (Service service) =>
      deleteFile('${service.id}_service.json');
  nppOperationHooks.preDeleteServiceACL = (ServiceACL serviceACL) =>
      deleteFile('${serviceACL.id}_service_acl.json');
  return nppOperationHooks;
}
