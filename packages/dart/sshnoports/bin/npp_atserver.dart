import 'dart:async';
import 'dart:io';
import 'package:at_client/at_client.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/admin.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/sshnp_foundation.dart' hide standardAtClientStoragePath;
import 'package:sshnoports/src/create_at_client_cli.dart';

late AtSignLogger logger;
void main(List<String> args) async {
  var p = await NPAParams.fromArgs(args);

  // Check atKeyFile selected exists
  if (!await File(p.atKeysFilePath).exists()) {
    throw ('\n Unable to find .atKeys file : ${p.atKeysFilePath}');
  }

  AtSignLogger.root_level = 'SHOUT';
  if (p.verbose) {
    AtSignLogger.root_level = 'INFO';
  }
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;

  logger = AtSignLogger(' npp ');
  AtClient atClient = await createAtClientCli(
    atsign: p.authorizerAtsign,
    atKeysFilePath: p.atKeysFilePath,
    rootDomain: p.rootDomain,
    atServiceFactory: ServiceFactoryWithNoOpSyncService(),
    namespace: DefaultArgs.namespace,
    storagePath: standardAtClientStoragePath(
        baseDir: p.homeDirectory,
        atSign: p.authorizerAtsign,
        progName: '.${DefaultArgs.namespace}',
        uniqueID: 'single'),
  );

  Handler handler = Handler(atClient);
  await handler.init();

  logger.shout('Daemon atSigns: ${handler.daemonAtSigns}');
  var sshnpa = NPAImpl(
    atClient: atClient,
    homeDirectory: p.homeDirectory,
    daemonAtsigns: handler.daemonAtSigns,
    handler: handler,
  );

  if (p.verbose) {
    sshnpa.logger.logger.level = Level.INFO;
  }

  Set<String> notifiedDaemonAtSigns = {};

  atClient.notificationService
      .subscribe(
    regex: r'.*\.devices\.policy\.sshnp',
    shouldDecrypt: true,
  )
      .listen((AtNotification n) {
    notifiedDaemonAtSigns.add(n.from);
    sshnpa.daemonAtsigns.clear();
    sshnpa.daemonAtsigns.addAll(handler.api.daemonAtSigns);
    sshnpa.daemonAtsigns.addAll(notifiedDaemonAtSigns);
    logger.info('daemonAtSigns is now ${sshnpa.daemonAtsigns}');
  });

  atClient.notificationService
      .subscribe(
    regex: r'.*\.groups\.policy\.sshnp',
    shouldDecrypt: true,
  )
      .listen((AtNotification n) {
    sshnpa.daemonAtsigns.clear();
    sshnpa.daemonAtsigns.addAll(handler.api.daemonAtSigns);
    sshnpa.daemonAtsigns.addAll(notifiedDaemonAtSigns);
    logger.info('daemonAtSigns is now ${sshnpa.daemonAtsigns}');
  });

  await sshnpa.run();
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

  Set<String> get daemonAtSigns => api.daemonAtSigns;

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
