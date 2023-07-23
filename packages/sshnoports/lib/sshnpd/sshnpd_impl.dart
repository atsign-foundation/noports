import 'dart:async';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:sshnoports/common/create_at_client_cli.dart';
import 'package:sshnoports/common/utils.dart';
import 'package:sshnoports/sshnpd/sshnpd.dart';
import 'package:sshnoports/sshnpd/sshnpd_params.dart';
import 'package:sshnoports/version.dart';
import 'package:uuid/uuid.dart';

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

  /// State variables used by [_notificationHandler]
  String _privateKey = "";

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
      var p = SSHNPDParams.fromArgs(args);

      // Check atKeyFile selected exists
      if (!await fileExists(p.atKeysFilePath)) {
        throw ('\n Unable to find .atKeys file : ${p.atKeysFilePath}');
      }

      AtSignLogger.root_level = 'SHOUT';
      if (p.verbose) {
        AtSignLogger.root_level = 'INFO';
      }

      AtClient atClient = await createAtClientCli(
        homeDirectory: p.homeDirectory,
        atsign: p.deviceAtsign,
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
      printVersion();
      stdout.writeln(SSHNPDParams.parser.usage);
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
        ..namespace = SSHNPD.namespace
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

    logger.info('Subscribing to $device\\.${SSHNPD.namespace}@');
    notificationService
        .subscribe(regex: '$device\\.${SSHNPD.namespace}@', shouldDecrypt: true)
        .listen(
          _notificationHandler,
          onError: (e) => logger.severe('Notification Failed:$e'),
          onDone: () => logger.info('Notification listener stopped'),
        );
    logger.info('Done');
  }

  void _notificationHandler(AtNotification notification) async {
    String notificationKey = notification.key
        .replaceAll('${notification.to}:', '')
        .replaceAll('.$device.${SSHNPD.namespace}${notification.from}', '')
        // convert to lower case as the latest AtClient converts notification
        // keys to lower case when received
        .toLowerCase();

    logger.info('Received: $notificationKey');
    switch (notificationKey) {
      case 'privatekey':
        logger.info(
            'Private Key received from ${notification.from} notification id : ${notification.id}');
        _privateKey = notification.value!;
        break;
      case 'sshpublickey':
        late final String sshPublicKey;
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
        break;
      case 'sshd':
        logger.info(
            'ssh callback request received from ${notification.from} notification id : ${notification.id}');
        _sshCallback(notification, _privateKey, logger, managerAtsign,
            deviceAtsign, device);
        break;
    }
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
    String sshString = notification.value!;

    var metaData = Metadata()
      ..isPublic = false
      ..isEncrypted = true
      ..namespaceAware = true
      ..ttr = -1
      ..ttl = 10000;

    /// Setup an atKey to return a notification to the managerAtsign
    var atKey = AtKey()
      ..key = '$sessionId.$device'
      ..sharedBy = deviceAtsign
      ..sharedWith = managerAtsign
      ..namespace = SSHNPD.namespace
      ..metadata = metaData;

    if (notification.from != managerAtsign) {
      logger.shout(
          'ssh session attempted from: ${notification.from} session: $sessionId and ignored');
      return;
    }

    /// Local port, port of sshd, username, hostname
    List<String> sshList = sshString.split(' ');
    var localPort = sshList[0];
    var port = sshList[1];
    var username = sshList[2];
    var hostname = sshList[3];

    /// Assure backward compatibility with 1.x clients
    if (sshList.length == 5) {
      sessionId = sshList[4];
      atKey = AtKey()
        ..key = '$sessionId.$device'
        ..sharedBy = deviceAtsign
        ..sharedWith = managerAtsign
        ..namespace = SSHNPD.namespace
        ..metadata = metaData;
    }

    logger.info(
        'ssh session started for $username to $hostname on port $port using localhost:$localPort on $hostname ');
    logger.shout(
        'ssh session started from: ${notification.from} session: $sessionId');

    try {
      final pemFile = File('/tmp/.pem-${Uuid().v4()}');
      pemFile.writeAsStringSync(privateKey);
      await Process.run('chmod', ['go-rwx', pemFile.absolute.path]);

      bool running = true;
      // When we receive notification 'sshd', WE are going to ssh to the host and port provided by sshnp
      // which could be the host and port of a client machine, or the host and port of an sshrvd which is
      // joined via socket connector to the client machine. Let's call it targetHostName/Port
      //
      // so: ssh username@targetHostName -p targetHostPort
      //
      // We're not providing a stdin so we use '-t -t' to get ssh to create a pseudo-terminal anyway
      //
      // We need to use the private key which the client sent to us (and we just stored in a tmp file)
      // This is done by adding '-i <pemFile>' to the ssh command
      //
      // When we make the connection (remember we are the client) we want to tell the client
      // to listen on some port and forward all connections to that port to port 22 on sshnpd's host.
      // The incantation for that is -R clientHostPort:localhost:22
      //
      // Lastly, we want to ensure that if the connection isn't used then it closes after 15 seconds
      // or once the last connection via the remote port has ended. For that we append 'sleep 15' to
      // the ssh command.
      //
      // ssh username@targetHostName -p remote -i $pemFile -R clientHostPort:localhost:22 sleep 15
      List<String> args = ['$username@$hostname', '-p', port, '-t', '-t', '-i', pemFile.absolute.path, '-R', '$localPort:localhost:22', 'sleep', '15'];
      logger.info('$sessionId | Executing /usr/bin/ssh ${args.join(' ')}');
      unawaited(Process.run('/usr/bin/ssh', args)
        .then((ProcessResult result) {
          running = false;
          if (result.exitCode != 0) {
            logger.shout('$sessionId | Non-zero exit code from /usr/bin/ssh ${args.join(' ')}');
            logger.shout('$sessionId | stdout   : ${result.stdout}');
            logger.shout('$sessionId | stderr   : ${result.stderr}');
          } else {
            logger.shout('$sessionId | ssh session ended');
          }
          if (pemFile.existsSync()) {
            pemFile.deleteSync();
          }
        })
          .onError((error, stackTrace) {
            running = false;
            if (pemFile.existsSync()) {
              pemFile.deleteSync();
            }
            logger.shout('$sessionId | Error $error from running /usr/bin/ssh ${args.join(' ')}');
      }));
      await Future.delayed(Duration(milliseconds: 500));
      if (pemFile.existsSync()) {
        pemFile.deleteSync();
      }

      if (! running) {
        logger.warning('Failed to forward remote port $localPort');
        // Notify sshnp that this session is NOT connected
        await _notify(
          atKey,
          'Failed to forward remote port $localPort, (use --local-port to specify unused port)',
          sessionId: sessionId,
        );
        return;
      }

      /// Notify sshnp that the connection has been made
      logger.info(' sshnpd connected notification sent to:from "$atKey');
      await _notify(atKey, "connected", sessionId: sessionId);

    } catch (e) {
      logger.severe('SSH Client failure : $e');
      // Notify sshnp that this session is NOT connected
      await _notify(
        atKey,
        'Remote SSH Client failure : $e',
        sessionId: sessionId,
      );
    }
  }

  Future<void> _notify(AtKey atKey, String value,
      {String sessionId = ""}) async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    NotificationService notificationService = atClient.notificationService;

    await notificationService
        .notify(NotificationParams.forUpdate(atKey, value: value),
            onSuccess: (notification) {
      logger.info('SUCCESS:$notification for: $sessionId with value: $value');
    }, onError: (notification) {
      logger.info('ERROR:$notification');
    });
  }
}
