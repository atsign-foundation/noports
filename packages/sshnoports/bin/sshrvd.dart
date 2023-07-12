// dart packages
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

// atPlatform packages
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';

// external packages
import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:version/version.dart';

// local packages
import 'package:sshnoports/version.dart';
import 'package:sshnoports/shared/utils.dart';

void main(List<String> args) async {
  final AtSignLogger logger = AtSignLogger(' sshrvd ');
  logger.hierarchicalLoggingEnabled = true;
  logger.logger.level = Level.SHOUT;
  late AtClient atClient;
  String session = '';
  String atSign = 'unknown';
  String forAtsign = '';
  String? homeDirectory = getHomeDirectory();
  dynamic results;
  String atsignFile;
  String managerAtsign = 'unknown';
  String ipAddress;
  String nameSpace = 'sshrvd';
  bool snoop = false;

  // Get the command line arguments to fill in the details
  var parser = ArgParser();
  // Basic arguments
  parser.addOption('key-file',
      abbr: 'k',
      mandatory: false,
      help: 'atSign\'s atKeys file if not in ~/.atsign/keys/');
  parser.addOption('atsign',
      abbr: 'a', mandatory: true, help: 'atSign for sshrvd');
  parser.addOption('manager',
      abbr: 'm',
      defaultsTo: 'open',
      mandatory: false,
      help: 'Managers atSign that sshrvd will accept requests from. Default is any atSign can use sshrvd');
  parser.addOption('ip',
      abbr: 'i', mandatory: true, help: 'FQDN/IP address sent to clients');

  parser.addFlag('verbose', abbr: 'v', help: 'More logging');

  parser.addFlag('snoop',
      abbr: 's',
      defaultsTo: false,
      help: 'Snoop on traffic passing through service');

  try {
    // Arg check
    results = parser.parse(args);
    // Find atSign key file
    atSign = results['atsign'];
    ipAddress = results['ip'];
    managerAtsign = results['manager'];
    if (results['key-file'] != null) {
      atsignFile = results['key-file'];
    } else {
      atsignFile = '${atSign}_key.atKeys';
      atsignFile = '$homeDirectory/.atsign/keys/$atsignFile';
    }
    // Check atKeyFile selected exists
    if (!await fileExists(atsignFile)) {
      throw ('\n Unable to find .atKeys file : $atsignFile');
    }

    // Add a namespace separator just cause its neater.
  } catch (e) {
    version();
    stdout.writeln(parser.usage);
    stderr.writeln(e);
    exit(1);
  }

  // Logging setup
  AtSignLogger.root_level = 'WARNING';
  logger.logger.level = Level.WARNING;
  if (results['verbose']) {
    logger.logger.level = Level.INFO;

    AtSignLogger.root_level = 'INFO';
  }

  snoop = results['snoop'];



  // Now on to the atPlatform startup
  //onboarding preference builder can be used to set onboardingService parameters
  AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    //..qrCodePath = '<location of image>'
    ..hiveStoragePath = '$homeDirectory/.sshrvd/$atSign/storage'
    ..namespace = nameSpace
    ..downloadPath = '$homeDirectory/.sshrvd/files'
    ..isLocalStoreRequired = true
    ..commitLogPath = '$homeDirectory/.sshrvd/$atSign/storage/commitLog'
    ..fetchOfflineNotifications = false
    ..atKeysFilePath = atsignFile
    ..atProtocolEmitted = Version(2, 0, 0);

  AtOnboardingService onboardingService =
      AtOnboardingServiceImpl(atSign, atOnboardingConfig);

  await onboardingService.authenticate();

  atClient = AtClientManager.getInstance().atClient;

  NotificationService notificationService = atClient.notificationService;

  notificationService
      .subscribe(regex: '$nameSpace@', shouldDecrypt: true)
      .listen(((notification) async {
    if (notification.key.contains(nameSpace)) {
      session = notification.value!;
      forAtsign = notification.from;
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
          ..namespace = nameSpace
          ..metadata = metaData;

        String data = '$ipAddress,${ports[0]},${ports[1]}';

        try {
          await atClient.notificationService.notify(
              NotificationParams.forUpdate(atKey, value: data),
              waitForFinalDeliveryStatus: false,
              checkForFinalDeliveryStatus: false);
        } catch (e) {
          stderr.writeln("Error writting session ${notification.value} atKey");
        }
      } else {
        logger.shout('Session $session for $forAtsign denied');
      }
    }
  }
  )
  );
}

Future<List<int>> connectSpawn(
    int portA, int portB, String session, String forAtsign, bool snoop) async {
  /// Spawn an isolate, passing my receivePort sendPort

  ReceivePort myReceivePort = ReceivePort();
  unawaited(Isolate.spawn<SendPort>(connect, myReceivePort.sendPort));

  SendPort mySendPort = await myReceivePort.first;

  myReceivePort = ReceivePort();
  mySendPort
      .send([portA, portB, session, forAtsign, snoop, myReceivePort.sendPort]);

  List message = await myReceivePort.first as List;

  portA = message[0];
  portB = message[1];

  return ([portA, portB]);
}

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
