import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:sshnoports/common/create_at_client_cli.dart';
import 'package:sshnoports/common/utils.dart';
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
      stderr.writeln(e);
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
        .listen(((notification) async {
      if (notification.key.contains(SSHRVD.namespace)) {
        String session = notification.value!;
        String forAtsign = notification.from;
        if (forAtsign == managerAtsign || managerAtsign == 'open') {
          var ports = await connectSpawn(0, 0, session, forAtsign, snoop);
          logger.warning(
              'Starting session $session for $forAtsign using ports $ports');

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

          String data = '$ipAddress,${ports[0]},${ports[1]}';

          try {
            await atClient.notificationService.notify(
                NotificationParams.forUpdate(atKey, value: data),
                waitForFinalDeliveryStatus: false,
                checkForFinalDeliveryStatus: false);
          } catch (e) {
            stderr
                .writeln("Error writting session ${notification.value} atKey");
          }
        } else {
          logger.shout('Session $session for $forAtsign denied');
        }
      }
    }));
  }

  @override
  Future<List<int>> connectSpawn(int portA, int portB, String session,
      String forAtsign, bool snoop) async {
    /// Spawn an isolate, passing my receivePort sendPort

    ReceivePort myReceivePort = ReceivePort();
    unawaited(Isolate.spawn<SendPort>(connect, myReceivePort.sendPort));

    SendPort mySendPort = await myReceivePort.first;

    myReceivePort = ReceivePort();
    mySendPort.send(
        [portA, portB, session, forAtsign, snoop, myReceivePort.sendPort]);

    List message = await myReceivePort.first as List;

    portA = message[0];
    portB = message[1];

    return ([portA, portB]);
  }

  @override
  Future<void> connect(SendPort mySendPort) async {
    final AtSignLogger logger = AtSignLogger(' sshrvd ');
    logger.hierarchicalLoggingEnabled = true;

    AtSignLogger.root_level = 'WARNING';
    logger.logger.level = Level.WARNING;

    int portA = 0;
    int portB = 0;
    String session;
    String forAtsign;
    bool verbose = false;
    ReceivePort myReceivePort = ReceivePort();
    mySendPort.send(myReceivePort.sendPort);

    List message = await myReceivePort.first as List;
    portA = message[0];
    portB = message[1];
    session = message[2];
    forAtsign = message[3];
    verbose = message[4];
    mySendPort = message[5];

    SocketConnector socketStream = await SocketConnector.serverToServer(
      serverAddressA: InternetAddress.anyIPv4,
      serverAddressB: InternetAddress.anyIPv4,
      serverPortA: portA,
      serverPortB: portB,
      verbose: verbose,
    );

    portA = socketStream.senderPort()!;
    portB = socketStream.receiverPort()!;

    mySendPort.send([portA, portB]);

    // await Future.delayed(Duration(seconds: 10));
    bool closed = false;
    while (closed == false) {
      closed = await socketStream.closed();
    }

    logger.warning(
        'Finished session $session for $forAtsign using ports [$portA, $portB]');
  }
}
