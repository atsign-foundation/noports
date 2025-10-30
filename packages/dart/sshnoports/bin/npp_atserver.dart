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
  } catch (err) {
    stderr.writeln(err);
    exit(3);
  }

  Handler handler = Handler(atClient);
  try {
    await handler.init();
  } catch (err) {
    stderr.writeln(err);
    exit(4);
  }

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

  // start updating the heartbeat atkey periodically
  Timer.periodic(const Duration(seconds: 60), (_) async {
    await _updateHeartbeatKey(atClient); // key format: `heartbeat.noports@<atsign>`: {'timestamp': '...'}
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
