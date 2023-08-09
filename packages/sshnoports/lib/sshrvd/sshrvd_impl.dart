import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:sshnoports/common/create_at_client_cli.dart';
import 'package:sshnoports/common/utils.dart';
import 'package:sshnoports/sshrvd/socket_connector.dart';
import 'package:sshnoports/sshrvd/sshrvd.dart';
import 'package:sshnoports/sshrvd/sshrvd_params.dart';
import 'package:sshnoports/version.dart';

class SSHRVDImpl implements SSHRVD {
  @override
  final AtSignLogger logger = AtSignLogger(' sshrvd ');
  @override
  AtClient atClient;
  @override
  final String atSign;
  @override
  final String homeDirectory;
  @override
  final String atKeysFilePath;
  @override
  final String managerAtsign;
  @override
  final String ipAddress;
  @override
  final bool snoop;

  @override
  @visibleForTesting
  bool initialized = false;

  SSHRVDImpl({
    required this.atClient,
    required this.atSign,
    required this.homeDirectory,
    required this.atKeysFilePath,
    required this.managerAtsign,
    required this.ipAddress,
    required this.snoop,
  }) {
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;
  }

  static Future<SSHRVD> fromCommandLineArgs(List<String> args) async {
    try {
      var p = SSHRVDParams.fromArgs(args);

      if (!await fileExists(p.atKeysFilePath)) {
        throw ('\n Unable to find .atKeys file : ${p.atKeysFilePath}');
      }

      AtSignLogger.root_level = 'SHOUT';
      if (p.verbose) {
        AtSignLogger.root_level = 'INFO';
      }

      AtClient atClient = await createAtClientCli(
        homeDirectory: p.homeDirectory,
        subDirectory: '.sshrvd',
        atsign: p.atSign,
        atKeysFilePath: p.atKeysFilePath,
        namespace: SSHRVD.namespace,
        rootDomain: p.rootDomain,
      );

      var sshrvd = SSHRVD(
        atClient: atClient,
        atSign: p.atSign,
        homeDirectory: p.homeDirectory,
        atKeysFilePath: p.atKeysFilePath,
        managerAtsign: p.managerAtsign,
        ipAddress: p.ipAddress,
        snoop: p.snoop,
      );

      if (p.verbose) {
        sshrvd.logger.logger.level = Level.INFO;
      }
      return sshrvd;
    } catch (e) {
      printVersion();
      stdout.writeln(SSHRVDParams.parser.usage);
      stderr.writeln('\n$e');
      rethrow;
    }
  }

  @override
  Future<void> init() async {
    if (initialized) {
      throw StateError('Cannot init() - already initialized');
    }

    initialized = true;
  }

  @override
  Future<void> run() async {
    if (!initialized) {
      throw StateError('Cannot run() - not initialized');
    }
    NotificationService notificationService = atClient.notificationService;

    notificationService
        .subscribe(regex: '${SSHRVD.namespace}@', shouldDecrypt: true)
        .listen(_notificationHandler);
  }

  void _notificationHandler(AtNotification notification) async {
    if (!notification.key.contains(SSHRVD.namespace)) {
      // ignore notifications not for this namespace
      return;
    }

    String session = notification.value!;
    String forAtsign = notification.from;

    if (managerAtsign != 'open' && managerAtsign != forAtsign) {
      logger.shout('Session $session for $forAtsign denied');
      return;
    }

    (int, int) ports =
        await _spawnSocketConnector(0, 0, session, forAtsign, snoop);
    var (portA, portB) = ports;
    logger
        .warning('Starting session $session for $forAtsign using ports $ports');

    var metaData = Metadata()
      ..isPublic = false
      ..isEncrypted = true
      ..ttr = -1
      ..ttl = 10000
      ..namespaceAware = true;

    var atKey = AtKey()
      ..key = notification.value
      ..sharedBy = atSign
      ..sharedWith = notification.from
      ..namespace = SSHRVD.namespace
      ..metadata = metaData;

    String data = '$ipAddress,$portA,$portB';

    try {
      await atClient.notificationService.notify(
          NotificationParams.forUpdate(atKey, value: data),
          waitForFinalDeliveryStatus: false,
          checkForFinalDeliveryStatus: false);
    } catch (e) {
      stderr.writeln("Error writting session ${notification.value} atKey");
    }
  }

  /// This function spawns a new socketConnector in a background isolate
  /// once the socketConnector has spawned and is ready to accept connections
  /// it sends back the port numbers to the main isolate
  /// then the port numbers are returned from this function
  Future<PortPair> _spawnSocketConnector(
    int portA,
    int portB,
    String session,
    String forAtsign,
    bool snoop,
  ) async {
    /// Spawn an isolate and wait for it to send back the issued port numbers
    ReceivePort receivePort = ReceivePort(session);

    ConnectorParams parameters =
        (receivePort.sendPort, portA, portB, session, forAtsign, snoop);

    logger
        .info("Spawning socket connector isolate with parameters $parameters");

    unawaited(Isolate.spawn<ConnectorParams>(socketConnector, parameters));

    PortPair ports = await receivePort.first;

    logger.info('Received ports $ports in main isolate for session $session');

    return ports;
  }
}
