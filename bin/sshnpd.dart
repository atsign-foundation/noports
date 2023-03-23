// dart packages
import 'dart:async';
import 'dart:io';

// atPlatform packages
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';

// external packages
import 'package:args/args.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

// local packages
import 'package:sshnoports/version.dart';
import 'package:sshnoports/home_directory.dart';
import 'package:sshnoports/check_non_ascii.dart';
import 'package:sshnoports/check_file_exists.dart';
import 'package:version/version.dart';

void main(List<String> args) async {
  try {
    await _main(args);
  } catch (error, stackTrace) {
    stderr.writeln('sshnpd: ${error.toString()}');
    stderr.writeln('stack trace: ${stackTrace.toString()}');
    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  }
}

Future<void> _main(List<String> args) async {
  final AtSignLogger logger = AtSignLogger(' sshnpd ');
  late AtClient? atClient;
  String nameSpace = '';

  var parser = ArgParser();
  // Basic arguments
  parser.addOption('keyFile',
      abbr: 'k',
      mandatory: false,
      help: 'Sending atSign\'s keyFile if not in ~/.atsign/keys/');
  parser.addOption('atsign',
      abbr: 'a', mandatory: true, help: 'atSign of this device');
  parser.addOption('manager',
      abbr: 'm',
      mandatory: true,
      help: 'Managers atSign, that this device will accept triggers from');
  parser.addOption('device',
      abbr: 'd',
      mandatory: false,
      defaultsTo: "default",
      help:
          'Send a trigger to this device, allows multiple devices share an atSign');

  parser.addFlag('sshpublickey',
      abbr: 's',
      help: 'Update authorized_keys to include public key from sshnp');
  parser.addFlag('username',
      abbr: 'u',
      help:
          'Send username to the manager to allow sshnp to display username in command line');
  parser.addFlag('verbose', abbr: 'v', help: 'More logging');

  // Check the arguments
  dynamic results;
  String username = "nobody";
  String atsignFile;
  String deviceAtsign = 'unknown';
  String device = "";
  String managerAtsign = 'unknown';
  String? homeDirectory = getHomeDirectory();

  try {
    // Arg check
    results = parser.parse(args);

    // Do we have a username ?
    Map<String, String> envVars = Platform.environment;
    if (Platform.isLinux || Platform.isMacOS) {
      username = envVars['USER'].toString();
    } else if (Platform.isWindows) {
      username = envVars['\$env:username'].toString();
    }
    if (username == 'nobody') {
      throw ('\nUnable to determine your username: please set environment variable\n\n');
    }
    if (homeDirectory == null) {
      throw ('\nUnable to determine your home directory: please set environment variable\n\n');
    }
    if (checkNonAscii(results['device'])) {
      throw ('\nDevice name can only contain alphanumeric characters with a max length of 15');
    }
    device = results['device'];

    // Find atSign key file
    if (results['keyFile'] != null) {
      atsignFile = results['keyFile'];
    } else {
      deviceAtsign = results['atsign'];
      managerAtsign = results['manager'];
      atsignFile = '${deviceAtsign}_key.atKeys';
    }
    atsignFile = '$homeDirectory/.atsign/keys/$atsignFile';
    // Check atKeyFile selected exists
    if (!await fileExists(atsignFile)) {
      throw ('\n Unable to find .atKeys file : $atsignFile');
    }
  } catch (e) {
    (e);
    version();
    stdout.writeln(parser.usage);
    exit(0);
  }

  logger.hierarchicalLoggingEnabled = true;
  logger.logger.level = Level.SHOUT;

  AtSignLogger.root_level = 'SHOUT';
  if (results['verbose']) {
    logger.logger.level = Level.INFO;

    AtSignLogger.root_level = 'INFO';
  }

  //onboarding preference builder can be used to set onboardingService parameters
  AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    //..qrCodePath = 'etc/qrcode_blueamateurbinding.png'
    ..hiveStoragePath = '$homeDirectory/.sshnp/$deviceAtsign/storage'
    ..namespace = 'sshnp'
    ..downloadPath = '$homeDirectory/.sshnp/files'
    ..isLocalStoreRequired = true
    ..commitLogPath = '$homeDirectory/.sshnp/$deviceAtsign/storage/commitLog'
    //..cramSecret = '<your cram secret>';
    ..fetchOfflineNotifications = false
    ..atKeysFilePath = atsignFile
    ..atProtocolEmitted = Version(2, 0, 0);
  nameSpace = atOnboardingConfig.namespace!;

  AtOnboardingService onboardingService =
      AtOnboardingServiceImpl(deviceAtsign, atOnboardingConfig);

  await onboardingService.authenticate();

  atClient = AtClientManager.getInstance().atClient;

  bool syncComplete = false;
  void onSyncDone(syncResult) {
    logger.info("syncResult.syncStatus: ${syncResult.syncStatus}");
    logger.info("syncResult.lastSyncedOn ${syncResult.lastSyncedOn}");
    syncComplete = true;
  }

  // Wait for initial sync to complete
  logger.shout("Starting $deviceAtsign sync");
  syncComplete = false;
  // TODO Use SyncProgressListener instead
  // ignore: deprecated_member_use
  atClient.syncService.sync(onDone: onSyncDone);
  while (!syncComplete) {
    await Future.delayed(Duration(milliseconds: 100));
  }
  logger.shout("$deviceAtsign sync complete");

  // If it was OK to send the username to the sshnp client set it up
  if (results['username']) {
    var metaData = Metadata()
      ..isPublic = false
      ..isEncrypted = true
      ..namespaceAware = true;

    var atKey = AtKey()
      ..key = "username.$device"
      ..sharedBy = deviceAtsign
      ..sharedWith = managerAtsign
      ..namespace = nameSpace
      ..metadata = metaData;

    await atClient.put(atKey, username);
  }

  // Keep an eye on connectivity and report failures if we see them
  ConnectivityListener().subscribe().listen((isConnected) {
    if (isConnected) {
      logger.warning('connection available');
    } else {
      logger.warning('connection lost');
    }
  });

  NotificationService notificationService = atClient.notificationService;

  String privateKey = "";
  String sshPublicKey = "";
  notificationService
      .subscribe(regex: '$device.$nameSpace@', shouldDecrypt: true)
      .listen(((notification) async {
    String notificationKey = notification.key
        .replaceAll('${notification.to}:', '')
        .replaceAll('.$device.$nameSpace${notification.from}', '')
        // convert to lower case as the latest AtClient converts notification
        // keys to lower case when received
        .toLowerCase();

    if (notificationKey == 'privatekey') {
      logger.info(
          'Private Key received from ${notification.from} notification id : ${notification.id}');
      privateKey = notification.value!;
    }

    if (notificationKey == 'sshpublickey') {
      try {
        var sshHomeDirectory = "$homeDirectory/.ssh/";
        if (Platform.isWindows) {
          sshHomeDirectory = '$homeDirectory\\.ssh\\';
        }
        logger.info(
            'ssh Public Key received from ${notification.from} notification id : ${notification.id}');
        sshPublicKey = notification.value!;

        // Check to see if the public key looks like one!
        if (!sshPublicKey.startsWith('ssh-rsa')) {
          throw ('$sshPublicKey does not look like a public key');
        }

        // Check to see if the ssh Publickey is already in the file if not append to the ~/.ssh/authorized_keys file
        var authKeys = File('${sshHomeDirectory}authorized_keys');

        var authKeysContent = await authKeys.readAsString();

        if (!authKeysContent.contains(sshPublicKey)) {
          authKeys.writeAsStringSync(sshPublicKey, mode: FileMode.append);
        }
      } catch (e) {
        logger.severe(
            'Error writing to $username .ssh/authorized_keys file : $e');
      }
    }

    if (notificationKey == 'sshd') {
      logger.info(
          'ssh callback request received from ${notification.from} notification id : ${notification.id}');
      sshCallback(notification, privateKey, logger, managerAtsign, deviceAtsign,
          nameSpace, device);
    }
  }),
          onError: (e) => logger.severe('Notification Failed:$e'),
          onDone: () => logger.info('Notification listener stopped'));
}

void sshCallback(
    AtNotification notification,
    String privateKey,
    AtSignLogger logger,
    String managerAtsign,
    String deviceAtsign,
    String nameSpace,
    String device) async {
  // sessionId is local if we do not have a 2.0 client
  var uuid = Uuid();
  String sessionId = uuid.v4();

  var sshString = notification.value!;
  // Get atPlatform notifications ready
  var metaData = Metadata()
    ..isPublic = false
    ..isEncrypted = true
    ..namespaceAware = true
    ..ttr = -1
    ..ttl = 10000;

  var atKey = AtKey()
    ..key = '$sessionId.$device'
    ..sharedBy = deviceAtsign
    ..sharedWith = managerAtsign
    ..namespace = nameSpace
    ..metadata = metaData;

  var atClient = AtClientManager.getInstance().atClient;
  NotificationService notificationService = atClient.notificationService;

  if (notification.from == managerAtsign) {
    // Local port, port of sshd , username , hostname
    List<String> sshList = sshString.split(' ');
    var localPort = sshList[0];
    var port = sshList[1];
    var username = sshList[2];
    var hostname = sshList[3];
    // Assure backward compatibility with 1.x clients
    if (sshList.length == 5) {
      sessionId = sshList[4];
      atKey = AtKey()
        ..key = '$sessionId.$device'
        ..sharedBy = deviceAtsign
        ..sharedWith = managerAtsign
        ..namespace = nameSpace
        ..metadata = metaData;
    }
    logger.info(
        'ssh session started for $username to $hostname on port $port using localhost:$localPort on $hostname ');
    logger.shout(
        'ssh session started from: ${notification.from} session: $sessionId');

    // var result = await Process.run('ssh', sshList);

    try {
      final socket = await SSHSocket.connect(hostname, int.parse(port));

      final client = SSHClient(
        socket,
        username: username,
        identities: [
          // A single private key file may contain multiple keys.
          ...SSHKeyPair.fromPem(privateKey)
        ],
      );
      // connect back to ssh server/port
      await client.authenticated;
      // Do the port forwarding
      final forward = await client.forwardRemote(port: int.parse(localPort));

      if (forward == null) {
        logger.warning('Failed to forward remote port $localPort');
        try {
          // Say this session is NOT connected to client
          await notificationService.notify(
              NotificationParams.forUpdate(atKey,
                  value:
                      'Failed to forward remote port $localPort, (use --local-port to specify unused port)'),
              onSuccess: (notification) {
            logger.info('SUCCESS:$notification for: $sessionId');
          }, onError: (notification) {
            logger.info('ERROR:$notification');
          });
        } catch (e) {
          stderr.writeln(e.toString());
        }
        return;
      }

      /// Send a notification to tell sshnp connection is made
      ///

      try {
        // Say this session is connected to client
        logger.info(' sshnpd connected notification sent to:from "$atKey');
        await notificationService
            .notify(NotificationParams.forUpdate(atKey, value: "connected"),
                onSuccess: (notification) {
          logger.info('SUCCESS:$notification for: $sessionId');
        }, onError: (notification) {
          logger.info('ERROR:$notification');
        });
      } catch (e) {
        stderr.writeln(e.toString());
      }

      ///

      int counter = 0;
      bool stop = false;
      // Set up time to check to see if all connections are down
      Timer.periodic(Duration(seconds: 15), (timer) async {
        if (counter == 0) {
          client.close();
          await client.done;
          stop = true;
          timer.cancel();
          logger.shout(
              'ssh session complete for: ${notification.from} session: $sessionId');
        }
      });
      // Answer ssh requests until none are left open
      await for (final connection in forward.connections) {
        counter++;
        final socket = await Socket.connect('localhost', 22);

        // ignore: unawaited_futures
        connection.stream.cast<List<int>>().pipe(socket).whenComplete(() async {
          counter--;
        });
        // ignore: unawaited_futures
        socket.pipe(connection.sink);
        if (stop) break;
      }
    } catch (e) {
      // need to make sure things close
      logger.severe('SSH Client failure : $e');
      try {
        // Say this session is connected to client
        await notificationService.notify(
            NotificationParams.forUpdate(atKey,
                value: 'Remote SSH Client failure : $e'),
            onSuccess: (notification) {
          logger.info('SUCCESS:$notification for: $sessionId');
        }, onError: (notification) {
          logger.info('ERROR:$notification');
        });
      } catch (e) {
        stderr.writeln(e.toString());
      }
    }
  }
}
