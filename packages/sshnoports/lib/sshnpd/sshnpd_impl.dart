// dart packages
import 'dart:async';
import 'dart:io';

// atPlatform packages
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_utils/at_logger.dart';
import 'package:at_client/at_client.dart';

// external packages
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:sshnoports/sshnpd/sshnpd.dart';
import 'package:sshnoports/sshnpd/sshnpd_cli_params.dart';
import 'package:version/version.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:uuid/uuid.dart';

// local packages
import 'package:sshnoports/version.dart';
import 'package:sshnoports/shared/service_factories.dart';

import '../shared/create_at_client_cli.dart';

const String nameSpace = 'sshnp';

class SSHNPDImpl implements SSHNPD {
  @override
  final AtSignLogger logger = AtSignLogger(' sshnpd ');

  @override
  late AtClient atClient;

  @override
  final String username;

  @override
  final String homeDirectory;

  @override
  final String device;

  @override
  String get deviceAtsign => atClient.getCurrentAtSign()!;

  @override
  late final String managerAtsign;

  @override
  @visibleForTesting
  bool initialized = false;

  static const String commandToSend = 'sshd';

  SSHNPDImpl(
      {
      // final fields
      required this.atClient,
      required this.username,
      required this.homeDirectory,
      // volatile fields
      required this.device,
      required this.managerAtsign}) {
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;
  }

  static Future<SSHNPD> fromCommandLineArgs(List<String> args) async {
    try {
      var p = SshnpdCliParams.fromArgs(args);

      // Check atKeyFile selected exists
      if (!File(p.atKeysFilePath).existsSync()) {
        throw ('\n Unable to find .atKeys file : ${p.atKeysFilePath}');
      }

      AtSignLogger.root_level = 'SHOUT';
      if (p.verbose) {
        AtSignLogger.root_level = 'INFO';
      }

      AtClient atClient = await createAtClientCli(
        homeDirectory: p.homeDirectory,
        atsign: p.deviceAtsign,
        // sessionId: sessionId, // This was not used in sshnpd
        atKeysFilePath: p.atKeysFilePath,
      );

      var sshnpd = SSHNPD(
        atClient: atClient,
        username: p.username,
        homeDirectory: p.homeDirectory,
        device: p.device,
        managerAtsign: p.managerAtsign,
      );

      if (p.verbose) {
        sshnpd.logger.logger.level = Level.INFO;
      }

      return sshnpd;
    } catch (e) {
      version();
      stdout.writeln(SshnpdCliParams.parser.usage);
      stderr.writeln(e);
      exit(1);
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

    if (username != '') {
      var metaData = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..ttr = -1
        ..namespaceAware = true;

      var atKey = AtKey()
        ..key = "username.$device"
        ..sharedBy = deviceAtsign
        ..sharedWith = managerAtsign
        ..namespace = nameSpace
        ..metadata = metaData;

      try {
        await notificationService.notify(
            NotificationParams.forUpdate(atKey, value: username),
            waitForFinalDeliveryStatus: false,
            checkForFinalDeliveryStatus: false, onSuccess: (notification) {
          logger.info('SUCCESS:$notification $username');
        }, onError: (notification) {
          logger.info('ERROR:$notification $username');
        });
      } catch (e) {
        stderr.writeln(e.toString());
      }
    }

    logger.info('Starting connectivity listener');
    // Keep an eye on connectivity and report failures if we see them
    ConnectivityListener().subscribe().listen((isConnected) {
      if (isConnected) {
        logger.warning('connection available');
      } else {
        logger.warning('connection lost');
      }
    });

    String privateKey = "";
    String sshPublicKey = "";
    logger.info('Subscribing to $device\\.$nameSpace@');
    notificationService
        .subscribe(regex: '$device\\.$nameSpace@', shouldDecrypt: true)
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

          // Check to see if the ssh public key looks like one!
          if (!sshPublicKey.startsWith('ssh-')) {
            throw ('$sshPublicKey does not look like a public key');
          }

          // Check to see if the ssh Publickey is already in the file if not append to the ~/.ssh/authorized_keys file
          var authKeys = File('${sshHomeDirectory}authorized_keys');

          var authKeysContent = await authKeys.readAsString();

          if (!authKeysContent.contains(sshPublicKey)) {
            authKeys.writeAsStringSync("\n$sshPublicKey",
                mode: FileMode.append);
          }
        } catch (e) {
          logger.severe(
              'Error writing to $username .ssh/authorized_keys file : $e');
        }
      }

      if (notificationKey == 'sshd') {
        logger.info(
            'ssh callback request received from ${notification.from} notification id : ${notification.id}');
        _sshCallback(notification, privateKey, logger, managerAtsign,
            deviceAtsign, device);
      }
    }),
            onError: (e) => logger.severe('Notification Failed:$e'),
            onDone: () => logger.info('Notification listener stopped'));
  }

  static Future<AtClient> createAtClient(
      {required String homeDirectory,
      required String deviceAtsign,
      required String sessionId,
      required String atKeysFilePath}) async {
    // Now on to the atPlatform startup
    //onboarding preference builder can be used to set onboardingService parameters
    AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
      ..hiveStoragePath = '$homeDirectory/.sshnp/$deviceAtsign/storage'
          .replaceAll('/', Platform.pathSeparator)
      ..namespace = 'sshnp'
      ..downloadPath =
          '$homeDirectory/.sshnp/files'.replaceAll('/', Platform.pathSeparator)
      ..isLocalStoreRequired = true
      ..commitLogPath = '$homeDirectory/.sshnp/$deviceAtsign/storage/commitLog'
          .replaceAll('/', Platform.pathSeparator)
      ..fetchOfflineNotifications = false
      ..atKeysFilePath = atKeysFilePath
      ..atProtocolEmitted = Version(2, 0, 0);

    AtOnboardingService onboardingService = AtOnboardingServiceImpl(
        deviceAtsign, atOnboardingConfig,
        atServiceFactory: ServiceFactoryWithNoOpSyncService());

    await onboardingService.authenticate();

    return AtClientManager.getInstance().atClient;
  }

  void _sshCallback(
      AtNotification notification,
      String privateKey,
      AtSignLogger logger,
      String managerAtsign,
      String deviceAtsign,
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
          connection.stream
              .cast<List<int>>()
              .pipe(socket)
              .whenComplete(() async {
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
    } else {
      logger.shout(
          'ssh session attempted from: ${notification.from} session: $sessionId and ignored');
    }
  }
}
