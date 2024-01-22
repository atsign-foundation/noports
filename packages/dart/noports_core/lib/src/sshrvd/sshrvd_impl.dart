import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/sshrvd/build_env.dart';
import 'package:noports_core/src/sshrvd/socket_connector.dart';
import 'package:noports_core/src/sshrvd/sshrvd.dart';
import 'package:noports_core/src/sshrvd/sshrvd_params.dart';

@protected
class SshrvdImpl implements Sshrvd {
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

  SshrvdImpl({
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

  static Future<Sshrvd> fromCommandLineArgs(List<String> args,
      {AtClient? atClient,
      FutureOr<AtClient> Function(SshrvdParams)? atClientGenerator,
      void Function(Object, StackTrace)? usageCallback}) async {
    try {
      var p = await SshrvdParams.fromArgs(args);

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

      var sshrvd = SshrvdImpl(
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
    } catch (e, s) {
      usageCallback?.call(e, s);
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
        .subscribe(regex: '${Sshrvd.namespace}@', shouldDecrypt: true)
        .listen(_notificationHandler);
  }

  void _notificationHandler(AtNotification notification) async {
    if (!notification.key.contains(Sshrvd.namespace)) {
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
      ..ttl = 10000
      ..namespaceAware = true;

    var atKey = AtKey()
      ..key = notification.value!
      ..sharedBy = atSign
      ..sharedWith = notification.from
      ..namespace = Sshrvd.namespace
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

    ConnectorParams parameters = (
      receivePort.sendPort,
      portA,
      portB,
      session,
      forAtsign,
      BuildEnv.enableSnoop && snoop,
    );

    logger
        .info("Spawning socket connector isolate with parameters $parameters");

    unawaited(Isolate.spawn<ConnectorParams>(socketConnector, parameters));

    PortPair ports = await receivePort.first;

    logger.info('Received ports $ports in main isolate for session $session');

    return ports;
  }
}
